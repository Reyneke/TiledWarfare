# 06 – Map Loader: Mapper-Guide

> **Zielgruppe:** Dieser Leitfaden richtet sich an Kartenersteller\*innen (Mapper), die mit **Tiled** (https://www.mapeditor.org/) neue Karten für TiledWarfare erstellen möchten. **Keine Programmierkenntnisse erforderlich.**

---

## 1. Überblick

TiledWarfare lädt Karten im **Tiled-Format** – entweder als `.tmx` (XML) oder `.tmj` (JSON).  
Das Spiel erwartet eine bestimmte **Layer-Struktur** und **Namenskonvention**, damit Boden, Dekoration, Kollision und Geländetypen korrekt erkannt werden.

Die wichtigsten Neuerungen:

- **Mehrere Layer** – statt einem einzigen Layer gibt es jetzt bis zu **5 verschiedene Ebenen**
- **Typsichere Layer-Zuordnung** – Layer werden über ihren **Namen** einem Zweck zugeordnet (z. B. `"ground"` = Boden)
- **Terrain-Typen** – über eine Objektgruppe können Geländetypen definiert werden (Wald, Wasser, Ruine etc.)
- **Zwei Dateiformate** – `.tmx` (XML) und `.tmj` (JSON) werden beide unterstützt

---

## 2. Unterstützte Dateiformate

| Format | Dateiendung | Beschreibung |
|--------|-------------|--------------|
| TMX | `.tmx` | XML-Format von Tiled – Standard |
| TMJ | `.tmj` | JSON-Format von Tiled – kompakter |

Der Parser erkennt automatisch an der Dateiendung, welches Format vorliegt.

### 2.1 Tile-Daten-Kodierung (nur TMX)

Bei TMX-Dateien werden die Tile-Daten in `<data>`-Elementen gespeichert.  
Folgende Kodierungen werden unterstützt:

| Kodierung | Kompression | Beschreibung |
|-----------|-------------|--------------|
| **CSV** | keine | Einfach, menschenlesbar – Kommata-getrennte Zahlen |
| **Base64** | keine | Kompakter, aber nicht lesbar |
| **Base64** | **zlib** | Komprimiert – **empfohlen** für große Karten |
| **Base64** | **gzip** | Alternativ-Kompression |

> **Empfehlung:** Verwenden Sie in Tiled bei "Map → Map Properties → Tile Layer Format" die Einstellung **"Base64 (zlib compressed)"**. Das spart Speicherplatz und wird von TiledWarfare effizient verarbeitet.

---

## 3. Das Layer-System

Eine Karte kann aus **mehreren Tile-Layern** bestehen. Jeder Layer hat einen **Namen** – und dieser Name bestimmt, wie der Layer vom Spiel verwendet wird.

### 3.1 Standard-Layer (nach Namen)

| Layer-Name | Purpose (Zweck) | Wird gezeichnet? | Beschreibung |
|------------|-----------------|------------------|--------------|
| `"ground"` | **Boden** | ✅ Ja, ganz unten | Grundfläche der Karte (z. B. Gras, Straße, Bodenplatten) |
| `"collision"` | **Kollision** | ❌ Nein, unsichtbar | Markiert unpassierbare Felder (jedes Tile != 0 = blockiert) |
| `"decoration"` | **Dekoration** | ✅ Ja, über dem Boden | Bäume, Steine, Büsche – werden über dem Boden gezeichnet |
| `"decoration - upper"` | **Obere Dekoration** | ✅ Ja, ganz oben | Dächer, Wolken, hohe Objekte – werden zuletzt gezeichnet |
| `"terrain"` | **Gelände** | ❌ Nein, unsichtbar | Enthält Geländetypen-Informationen (optional) |

### 3.2 Zeichen-Reihenfolge

Das Spiel zeichnet die Layer in dieser Reihenfolge:

```
1. ground      (unterste Ebene)
2. decoration  (Mitte)
3. decoration - upper (oberste Ebene)
```

Die Layer `"collision"` und `"terrain"` werden **nicht sichtbar gezeichnet**, sondern nur für Spiel-Logik verwendet (Kollisionserkennung, Geländekosten).

### 3.3 Beispiel: Aufbau einer Karte in Tiled

So sollte die Layer-Struktur im Tiled-Editor aussehen:

```
Layer Panel (von unten nach oben):
├── ground             ← Bodentiles (Gras, Straße, etc.)
├── collision          ← Kollisionstiles (unsichtbar)
├── decoration         ← Dekoration (Bäume, Büsche)
├── decoration - upper ← Obere Dekoration (Dächer)
└── terrain            ← Geländetypen (optional, unsichtbar)
```

**Wichtig:** Die Layer-Namen müssen **exakt** so geschrieben sein (Groß-/Kleinschreibung beachten!):

- `ground` ✅
- `collision` ✅
- `decoration` ✅
- `decoration - upper` ✅ (mit Leerzeichen vor und nach dem Bindestrich)
- `terrain` ✅

### 3.4 Kollisions-Layer

Der `"collision"`-Layer ist **unsichtbar** und dient nur der Kollisionserkennung.

- Jedes Tile mit einer **Tile-ID ≠ 0** wird als **blockiert** (unpassierbar) markiert.
- Tile-ID = 0 bedeutet freies Feld (keine Kollision).
- Sie können beliebige Tiles aus Ihrem Tileset verwenden – es wird nur geprüft, ob die ID ungleich 0 ist.

**Praxis-Tipp:** Erstellen Sie ein einfaches, rotes "X"- oder "Stop"-Tile in Ihrem Tileset und platzieren Sie es im `"collision"`-Layer. Das macht blockierte Felder im Editor sichtbar.

### 3.5 Layer-Eigenschaften (Opacity, Visible)

Zusätzlich zum Namen unterstützt jeder Layer:

- **Opacity** – Deckkraft (0.0 = unsichtbar, 1.0 = voll sichtbar). Kann im Tiled-Editor pro Layer eingestellt werden.
- **Visible** – Sichtbarkeit (`true`/`false`). Unsichtbare Layer werden zwar geladen, aber nicht gezeichnet.

---

## 4. Objektgruppen (Object Layers)

Neben Tile-Layern können Sie **Objektgruppen** (Object Layers) in Tiled anlegen.  
Zwei spezielle Objektgruppen werden von TiledWarfare ausgewertet:

### 4.1 Spawnpunkte: `"Spawns"`

In der Objektgruppe `"Spawns"` definieren Sie Startpositionen für Spieler und Monster.

| Objekt-Name | Zweck |
|-------------|-------|
| `spawn_player1` | Startposition Spieler 1 |
| `spawn_player2` | Startposition Spieler 2 |
| `spawn_player3` | Startposition Spieler 3 |
| `spawn_player4` | Startposition Spieler 4 |
| `spawn_monster` | Startposition Monster/Gegner |

So legen Sie einen Spawnpunkt an:

1. **Neue Objektgruppe** erstellen mit dem Namen `"Spawns"`
2. **Rechteck-Objekt** einfügen (Punkt-Objekte funktionieren auch)
3. Dem Objekt einen **Namen** geben (z. B. `spawn_player1`)
4. Die Koordinaten (x, y) werden automatisch aus der Position übernommen

**Wichtig:** Spawn-Objekte ohne Namen werden ignoriert.

### 4.2 Geländetypen: `"Gelaendetypen"`

In der Objektgruppe `"Gelaendetypen"` definieren Sie **Geländebereiche** mit speziellen Eigenschaften.

| Geländetyp (`type`-Feld) | Bewegungskosten | Blockiert Sicht? | Unpassierbar? |
|--------------------------|-----------------|------------------|---------------|
| `normal` | 1.0× (normal) | ❌ Nein | ❌ Nein |
| `ruin` | 2.0× (doppelt) | ✅ Ja | ❌ Nein |
| `forest` | 1.5× (1½-fach) | ✅ Ja | ❌ Nein |
| `water` | – | – | ✅ Ja (unpassierbar) |
| `wall` | – | ✅ Ja | ✅ Ja (unpassierbar) |
| `open_ground` | 1.0× (normal) | ❌ Nein | ❌ Nein |
| `swamp` | 3.0× (dreifach) | ❌ Nein | ❌ Nein |

So legen Sie einen Geländebereich an:

1. **Neue Objektgruppe** erstellen mit dem Namen `"Gelaendetypen"` (Großbuchstabe G am Anfang!)
2. **Rechteck-Objekt** einfügen, das den Geländebereich abdeckt
3. Dem Objekt unter **"Type"** (Typ) den Geländetyp zuweisen, z. B. `forest`
4. Position und Größe des Rechtecks bestimmen den Bereich (der Mittelpunkt des Rechtecks wird in Hex-Koordinaten umgerechnet)

**Wichtig:** Der Typ-Name muss **exakt** einem der obigen Werte entsprechen (alles Kleinschreibung, Unterstriche bei `open_ground`).

**Praxis-Tipp:** 

- Für **Wälder** legen Sie ein Rechteck über den Bereich, in dem Bäume stehen.
- Für **Ruinen** platzieren Sie ein Rechteck über das Ruinen-Gebäude.
- **Wasserflächen** und **Mauern** sind automatisch unpassierbar – zusätzlich können Sie blockierte Felder im `"collision"`-Layer markieren.

---

## 5. Tilesets

### 5.1 Unterstützte Tileset-Typen

TiledWarfare unterstützt zwei Arten von Tilesets:

| Typ | Beschreibung |
|-----|--------------|
| **Eingebettet (inline)** | Das Tileset wird direkt in der TMX/TMJ-Datei definiert inkl. Bildpfad |
| **Extern (TSX/JSON)** | Das Tileset wird aus einer separaten `.tsx`-Datei referenziert |

Beide Varianten funktionieren – für einfache Karten empfehlen wir **eingebettete Tilesets**.

### 5.2 Tileset-Bilder

- Das Tileset-Bild muss im gleichen Verzeichnis wie die TMX-Datei liegen (oder in einem Unterordner).
- Unterstützte Bildformate: **PNG** (empfohlen)
- Die Tile-Größe im Tileset muss mit der Karten-Tile-Größe übereinstimmen (Standard: 32×32 Pixel).
- Das Spiel unterstützt mehrere Tilesets pro Karte (z. B. eines für Boden, eines für Dekoration).

### 5.3 Wichtige Tileset-Parameter

| Parameter | Beschreibung |
|-----------|-------------|
| `firstgid` | Erste globale Tile-ID (wird von Tiled automatisch gesetzt) |
| `name` | Name des Tilesets |
| `tilewidth` / `tileheight` | Größe eines einzelnen Tiles in Pixeln |
| `tilecount` | Anzahl der Tiles im Tileset |
| `columns` | Anzahl der Spalten im Tileset-Bild |
| `image` | Pfad zum Tileset-Bild (relativ zur TMX-Datei) |

---

## 6. Karten-Metadaten (maps.json)

Neben der eigentlichen TMX/TMJ-Datei gibt es eine `maps.json`, die alle verfügbaren Karten auflistet.  
Diese Datei liegt im Verzeichnis `assets/maps/`.

**Beispiel:**
```json
[
  {
    "mapPath": "assets/maps/map0",
    "title": "Street Battle",
    "previewPath": "assets/maps/map0/preview.png",
    "tmxPath": "assets/maps/map0/street_battle.tmx"
  }
]
```

| Feld | Beschreibung |
|------|-------------|
| `mapPath` | Pfad zum Karten-Ordner |
| `title` | Anzeigename im Spiel |
| `previewPath` | Optional: Vorschaubild für die Kartenauswahl |
| `tmxPath` | Pfad zur `.tmx`- oder `.tmj`-Datei |

---

## 7. Karten-Orientierung

TiledWarfare unterstützt verschiedene Karten-Orientierungen:

| Orientierung | Beschreibung |
|-------------|-------------|
| `orthogonal` | Klassisches 4-Eck-Raster (Standard) |
| `isometric` | Isometrische Karten (2.5D-Look) |
| `hexagonal` | **Hex-Karten (empfohlen)** – das Hauptformat von TiledWarfare |
| `staggered` | Gestaffelte Karten (variante von orthogonal/hexagonal) |

Für Hex-Karten sind zusätzliche Parameter wichtig:

- **`staggeraxis`** = `"y"` (Standard) – Staffelungsachse
- **`staggerindex`** = `"odd"` (Standard) – Staffelungsindex

Diese Werte werden von Tiled automatisch gesetzt, wenn Sie ein neues Hex-Karten-Projekt anlegen.

---

## 8. Komplette Beispiel-Karte (Schritt-für-Schritt)

So erstellen Sie eine neue Karte, die von TiledWarfare geladen werden kann:

### Schritt 1: Neues Projekt in Tiled
- Datei → Neu → Neue Karte
- **Kartenbreite/-höhe:** z. B. 30×30 Felder
- **Tile-Größe:** 32×32 Pixel
- **Orientierung:** Hexagonal (gestaffelt, ungerade)
- **Tile-Layer-Format:** Base64 (zlib-komprimiert)
- Speichern als `.tmx` (oder `.tmj`)

### Schritt 2: Tileset hinzufügen
- Karte → Neues Tileset → "Neues Tileset erstellen..."
- Name: z. B. "Terrain"
- Typ: "Auf Basis eines Tileset-Bildes"
- Bild auswählen (z. B. ein 512×320 PNG mit 16 Spalten)
- Tile-Größe: 32×32

### Schritt 3: Layer anlegen
Im Layer-Fenster folgende Layer von unten nach oben anlegen:

1. `"ground"` (Tile-Layer) – Hier malen Sie den Boden
2. `"collision"` (Tile-Layer) – Hier markieren Sie blockierte Felder
3. `"decoration"` (Tile-Layer) – Hier platzieren Sie Bäume, Steine etc.
4. `"decoration - upper"` (Tile-Layer) – Hier platzieren Sie Dächer, hohe Objekte (optional)
5. `"Spawns"` (Objektgruppe) – Hier setzen Sie Spawnpunkte
6. `"Gelaendetypen"` (Objektgruppe) – Hier definieren Sie Geländebereiche (optional)

### Schritt 4: Karte bemalen
- `"ground"`-Layer auswählen und mit dem Boden-Tile bemalen
- `"collision"`-Layer auswählen und blockierte Felder markieren (jedes Tile ≠ 0 blockiert)
- `"decoration"`-Layer auswählen und Dekoration platzieren

### Schritt 5: Spawnpunkte setzen
- In der `"Spawns"`-Objektgruppe Rechtecke einfügen
- Objekt-Namen vergeben: `spawn_player1`, `spawn_monster` etc.

### Schritt 6: Geländetypen definieren (optional)
- In der `"Gelaendetypen"`-Objektgruppe Rechtecke einfügen
- Im Feld **"Type"** den Geländetyp eintragen (z. B. `forest`, `water`, `ruin`)
- Achten Sie auf korrekte Schreibweise (alles Kleinbuchstaben)

### Schritt 7: maps.json aktualisieren
Tragen Sie Ihre Karte in `assets/maps/maps.json` ein.

### Schritt 8: Speichern & Testen
- TMX-Datei speichern
- Tileset-Bild in den gleichen Ordner legen
- Spiel starten und prüfen, ob die Karte geladen wird

---

## 9. Häufige Fehler & Lösungen

| Problem | Mögliche Ursache | Lösung |
|---------|-----------------|--------|
| Karte wird nicht geladen | Falscher Pfad in `maps.json` | Prüfen Sie den `tmxPath` auf korrekte Schreibweise |
| "Unsupported map format" | Falsche Dateiendung | Nur `.tmx` oder `.tmj` |
| "Tile data length does not match" | Layer-Abmessungen passen nicht zur Karte | Layer-Größe in Tiled prüfen (muss Kartenbreite × -höhe sein) |
| Spiel zeigt weiße Fläche | Tileset-Bild nicht gefunden | Prüfen Sie den Bild-Pfad im Tileset |
| Kollision funktioniert nicht | `"collision"`-Layer fehlt oder falsch geschrieben | Layer-Namen exakt `"collision"` nennen |
| Spawnpunkte werden ignoriert | Objekte haben keinen Namen | Jeder Spawn-Punkt braucht einen Namen (`spawn_player1` etc.) |
| Geländetyp wird nicht erkannt | Falsche Schreibweise im Type-Feld | `forest` statt `Forrest`, `water` statt `Water` |

---

## 10. Technische Details (für Fortgeschrittene)

> Dieser Abschnitt ist optional – für Mapper, die verstehen möchten, was hinter den Kulissen passiert.

### 10.1 Der Ladevorgang im Überblick

```
TMX/TMJ-Datei
    │
    ▼
Parser (TmxParser oder TmjParser)
    │
    ├──→ Karten-Metadaten (Breite, Höhe, Tile-Größe, Orientierung)
    ├──→ Tile-Layers (ground, collision, decoration, etc.)
    ├──→ Tilesets (firstGid, Bild-Pfad)
    └──→ Objektgruppen (Spawns, Gelaendetypen)
           │
           ▼
     MapData (das zentrale Datenmodell)
           │
     ┌─────┼─────────┐
     ▼     ▼         ▼
  Zeichnen Kollision Gelände
  (Painter) (TerrainService)
```

### 10.2 Layer-Zuordnung (Name → Purpose)

Das Spiel verwendet folgende Standard-Zuordnung:

| Layer-Name im Tiled | LayerPurpose im Code |
|---------------------|---------------------|
| `"ground"` | `ground` |
| `"collision"` | `collision` |
| `"decoration"` | `decorative` |
| `"decoration - upper"` | `decorativeUpper` |
| `"terrain"` | `terrain` |
| *(alle anderen Namen)* | `unknown` |

Diese Zuordnung kann **nur im Code** angepasst werden, indem die `MapLoadConfig`-Klasse verwendet wird.

### 10.3 Besonderheiten der Hex-Karte

TiledWarfare verwendet ein **Odd-r-Hex-Gitter** (gestaffelte Reihen, ungerade Zeilen eingerückt):

- **Tile-Position:** Jedes Hex-Feld hat eine (x, y)-Koordinate im Gitter
- **Pixel-Position:** Wird über `hexToPixel(x, y)` berechnet
- **Hex-Key:** Eine eindeutige Integer-Kennung für jedes Feld → `hexKey = x * 100000 + y`
- **Nachbarschaft:** Jedes Hex hat 6 Nachbarn (Nordosten, Osten, Südosten, Südwesten, Westen, Nordwesten)

### 10.4 Performance-Optimierungen

Das Spiel verwendet folgende Techniken, um große Karten flüssig darzustellen:

- **Viewport-Culling:** Nur Tiles im sichtbaren Bereich werden gezeichnet
- **O(1)-Layer-Lookup:** Layer werden über einen vorberechneten Index angesprochen
- **RepaintBoundary:** Die Karte wird in einem eigenen Zeichen-Kontext gerendert
- **Vorberechnete Pixel-Positionen:** Hex→Pixel wird einmal beim Laden berechnet, nicht jedes Frame

---

## 11. Version & Historie

| Datum | Änderung |
|-------|----------|
| Juli 2026 | **Layer-System eingeführt** – mehrere Layer, LayerPurpose, O(1)-Lookups |
| Juli 2026 | **TMJ-Unterstützung** – JSON-Format von Tiled |
| Juli 2026 | **Terrain-System** – Geländetypen über Objektgruppe |
| Juli 2026 | **Mehrere Tilesets** – beliebig viele Tilesets pro Karte |
| Juli 2026 | **Base64/GZip-Unterstützung** – komprimierte Tile-Daten |

---

## 12. Weiterführende Links

- **Tiled Editor:** https://www.mapeditor.org/
- **TMX-Format (Dokumentation):** https://doc.mapeditor.org/en/stable/reference/tmx-map-format/
- **Hex-Gitter (Amit Patel):** https://www.redblobgames.com/grids/hexagons/
- **Projekt-Dokumentation:** `doc/00_project_overview.md`
- **Klassendiagramm:** `doc/01_class_diagram.md`