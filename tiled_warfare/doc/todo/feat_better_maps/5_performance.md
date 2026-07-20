### 5. Performance

#### Performance-Gewinn durch Viewport-Culling

| Kartengröße | Tiles gesamt | Sichtbare Tiles (≈) | Iterationen alt (3 Layer) | Iterationen neu (3 Layer) | Faktor |
|------------|-------------|---------------------|--------------------------|--------------------------|--------|
| 30×30      | 900         | ~50                 | 2.700                    | 150                      | 18×    |
| 100×100    | 10.000      | ~80                 | 30.000                   | 240                      | 125×   |
| 300×300    | 90.000      | ~120                | 270.000                  | 360                      | 750×   |

(Annahme: Viewport zeigt ~7×7 Tiles + 2 Padding ≈ ~11×11 ≈ 121, bei Hex-Geometrie ≈ 50–120 Tiles je nach Zoom-Stufe)

#### Umgesetzte Optimierungen

- **Viewport-Culling im `_HexMapPainter`**: Anstatt alle Tiles der Karte (`mapWidth × mapHeight`) zu durchlaufen und per `tileRect.overlaps(visibleRect)` zu cullen, wird der sichtbare Tile-Bereich vorab berechnet. Dadurch iteriert die Schleife nur noch über die tatsächlich sichtbaren Tiles (z. B. ~50 statt 10.000 bei großen Karten).

- **`RepaintBoundary` um die Karte**: Verhindert, dass Flutter die gesamte Widget-Baum-Hierarchie neu zeichnet, wenn sich nur die Karte ändert (z. B. beim Scrollen/Zoomen).

- **`Canvas.clipRect()` für GPU-Level-Clipping**: `canvas.save()` + `canvas.clipRect(visibleRect)` + `canvas.restore()` um die `paint()`-Methode. Dies teilt der GPU mit, dass Pixel außerhalb des sichtbaren Bereichs nicht gerendert werden müssen – eine Hardware-beschleunigte Optimierung.

- **Viewport-Berechnung einmal pro Frame**: Statt den sichtbaren Tile-Bereich in jedem `_drawLayer()`-Aufruf (3× pro Frame) neu zu berechnen, wird er in `paint()` einmal ermittelt und an alle Layer übergeben. Spart ~66 % Rechenzeit für die Bereichsberechnung.

- **`try-finally` für `canvas.save()/restore()`**: Stellt sicher, dass `canvas.restore()` auch bei Exceptions in `_drawLayer` aufgerufen wird – der GPU-Context bleibt konsistent.

- **`shouldRepaint` mit Tiefenvergleich**: Statt nur Referenzen zu vergleichen, werden auch Layer-Namen und Tile-Daten (`Uint32List`) verglichen. Das verhindert überflüssiges Neuzeichnen, wenn nur die `MapData`-Referenz wechselt, aber die Inhalte identisch sind.

- **`_pixelPositions` als `final` mit Konstruktor-Initializer**: Statt `late final` + Methode im Konstruktor wird eine `static`-Methode im Initializer-List verwendet. Kein `LateInitializationError`-Risiko mehr.

#### Details zu den Änderungen in `_drawLayer`

1. **Layer-Lookup optimiert**: Statt einer manuellen `for`-Schleife mit `break` wird `mapData.layers.where(...).firstOrNull` verwendet – kürzer und lesbarer.

2. **Berechnung des sichtbaren Tile-Bereichs** (`lib/widgets/widget_map_loader.dart`):
   ```dart
   const padding = 2;
   final startY = max(0, (visibleRect.top / (tileHeight * 3.0 / 4.0)).floor() - padding);
   final endY   = min(layer.height, (visibleRect.bottom / (tileHeight * 3.0 / 4.0)).ceil() + padding);
   final startX = max(0, (visibleRect.left / tileWidth).floor() - padding);
   final endX   = min(layer.width, (visibleRect.right / tileWidth).ceil() + padding);
   ```
   - Die y-Koordinate nutzt `tileHeight * 3/4`, da beim odd-r-Hex-Gitter die Zeilen um 75 % der Tile-Höhe versetzt sind.
   - Ein Padding von 2 Tiles auf jeder Seite fängt die odd-row-Verschiebung (`tileWidth / 2`) und Rundungsfehler ab.
   - Die Werte werden auf die Layer-Dimensionen geclamped, um out-of-bounds Zugriffe zu vermeiden.

3. **Die per-Tile `visibleRect.overlaps(tileRect)`-Abfrage entfällt**, da sie durch die Bereichseinschränkung der Schleife obsolet wird.

#### Speicherverbrauch: `_pixelPositions` (vorberechnete Hex-Positionen)

- `List<List<Offset>>` belegt `mapWidth × mapHeight × 16 Byte` (ein `Offset` = 2 × float64 = 16 Byte).
- 30×30: ~14 KB ✅
- 100×100: ~156 KB ✅
- 300×300: ~1,4 MB ⚠️ (könnte auf mobilen Geräten knapp werden)
- **Empfehlung:** Bei Karten > 200×200 auf On-Demand-Berechnung umschalten (`hexGrid.hexToPixel(x, y)` nur für sichtbare Tiles aufrufen).

#### Padding-Erklärung: Warum `padding = 2`?

Das Padding beträgt 2 Tiles pro Seite, weil:
1. **1 Tile** fängt die odd-row-Verschiebung (`tileWidth / 2`) ab – ungerade Zeilen sind horizontal versetzt.
2. **1 weiteres Tile** als Reserve für Subpixel-Rendering-Rundungsfehler (z. B. bei `floor()`/`ceil()`-Umrechnung).
3. Größere Werte (z. B. 3+) erhöhen die Anzahl der Schleifeniterationen.
4. Kleinere Werte (z. B. 1) riskieren visuelle Fehler an den Viewport-Rändern.

#### Probleme und Bugs (gefixt)

- **Zoom/Scroll**: Der sichtbare Bereich (`visibleRect`) entspricht der Größe des `CustomPaint`-Widgets. Da die Karte in einem `InteractiveViewer` steckt, der die Skalierung/Translation über die `Matrix4` des `TransformationController` steuert, ist `visibleRect` tatsächlich nur der (ggf. skalierte) Ausschnitt – **das Viewport-Culling funktioniert korrekt**, da `InteractiveViewer` die transformierte Größe an das Child weitergibt.

- **Padding zu klein?**: Bei sehr starkem Zoom-out könnte der sichtbare Bereich größer werden als die Karte selbst. Da `startX/Y` und `endX/Y` auf die Layer-Dimensionen geclamped werden (`max(0, ...)`, `min(layer.height/width, ...)`), ist das unproblematisch.

- **Thread-Sicherheit / async loading**: Optimierungen betreffen nur den `paint()`-Pfad. Das Laden (`_loadMap`) bleibt async im State-Widget – **keine Konflikte**.

- **`saveLayer()` vs. `clipRect()`**: `saveLayer()` ist teuer (erzeugt eine separate Rendering-Ebene). Stattdessen wurde `clipRect()` verwendet, das viel günstiger ist. Falls in Zukunft Effekte wie Transparenz oder Layer-Blending pro Layer nötig werden, könnte `saveLayer()` sinnvoll sein.

- ~~**`_precomputePositions()`**: Belegt `mapWidth × mapHeight × 16 Byte` (~8 KB für 30×30, ~800 KB für 300×300). Ist diese Liste nicht gesetzt, crasht `_drawLayer` mit `LateInitializationError`.~~ **Gefixt:** `late final` wurde durch `final` mit `static`-Konstruktor-Initializer ersetzt – kein `LateInitializationError`-Risiko mehr.

- ~~**`shouldRepaint` auf `tilesetImages` und `hexGrid`**: Diese Referenzen sind in der Praxis stabil. Falls `_HexMapPainter` neu erstellt wird (z. B. nach `setState` im State-Widget), stimmen die Referenzen nicht mehr überein und die Karte wird korrekt neu gezeichnet.~~ **Gefixt:** `shouldRepaint` führt jetzt Tiefenvergleich durch (Layer-Namen + Tile-Daten), nicht nur Referenzvergleich.

- ~~**`paint()` bei Exceptions**: Falls `_drawLayer` eine Exception wirft, wurde `canvas.restore()` nicht aufgerufen.~~ **Gefixt:** `try-finally`-Block um die `_drawLayer`-Aufrufe stellt `canvas.restore()` immer sicher.

#### Dokumentationsanpassungen

- `/doc/doc/04_cliffnotes.md`: Performance-Überlegungen zum `_HexMapPainter` ergänzen (Viewport-Culling + clipRect).
- `/doc/doc/05_new_employee_guide.md`: Hinweis auf die Architektur des Karten-Renderings – dass `_HexMapPainter` gezielt nur sichtbare Tiles zeichnet.
- `/doc/doc/01_class_diagram.md`: `_HexMapPainter` existiert nur als private Klasse in `widget_map_loader.dart` und ist im Diagramm ggf. noch nicht erfasst.

#### Nächste Schritte

- ~~**`shouldRepaint` verschärfen**: Aktuell wird bei jeder Änderung von `tilesetImages`, `mapData` oder `hexGrid` neu gezeichnet. Falls Performance-Messungen zeigen, dass zu oft repainted wird, könnte man tiefer vergleichen (z. B. Hash der geladenen Bilder).~~ **Erledigt** – `shouldRepaint` vergleicht jetzt Layer-Namen + Tile-Daten (`Uint32List`) tief.
- **`ImageCache` für Tilesets**: Wenn viele Karten geladen werden, könnten die Tileset-Bilder den Anwendungsspeicher aufblähen. Ein kontrollierter Cache (Entfernen alter Bilder beim Kartenwechsel) wäre sinnvoll. **Teilweise erledigt** – alte Bilder werden vor `_loadMap` disposet, aber es gibt noch keinen LRU-Cache für mehrere Karten.
- **Layer-Index-Map**: Für viele Layer (20+) könnte ein `Map<String, TileLayer>` die Lookup-Zeit verkürzen. Bei aktuell 3 Layern nicht nötig.

Wie würden sich diese Schritte auf die Dokumentation "/doc/doc" auswirken und was müsste, wenn diese Schritte umgesetzt werden, zusätzlich in dieser Dokumentation angepasst werden?