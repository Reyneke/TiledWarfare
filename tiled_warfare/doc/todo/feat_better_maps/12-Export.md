# Export der Tilemap Engine

Die ursprüngliche Tilemap-Engine entstand als Engine, welche eine Urban-Brawl-Umsetzung ermöglichen sollte. Leider stand das Projekt eine Weile still, aber jetzt geht es langsam wieder los. Daher ist die Überlegung, die aktuelle Tilemap-Engine in das Urban-Brawl-Projekt einzubinden – sofern dies möglich ist.

Dieses Dokument ist zunächst ein reines Planungsdokument zur Klärung aller Fragen und Erstellung eines Plans.

## Zu klärende Fragen und Entscheidungen

### Einbindungsform

**Frage:** Soll die Engine als eigenständiges Pub-Paket ausgelagert, als Git-Submodul/Pfadabhängigkeit eingebunden oder als Kopie in das Urban-Brawl-Projekt übernommen werden?

**Entscheidung:** Einbindung als **Git-Submodul** im OpenBrawl Repository. Dies dient hauptsächlich der Wartbarkeit: Die Engine soll hier weiterentwickelt werden, ohne ein zweites Repo für die Engine pflegen zu müssen. Änderungen, die hier im Projekt eintreten und die Engine betreffen, sollen direkt auch im OpenBrawl Projekt vertreten sein.

### Umfang

**Frage:** Welche Bestandteile sollen exportiert werden (TMX-Parser, Hex-Utility, Karten-Rendering, Spawn-/Objekt-Logik)?

**Antwort:** Da das OpenBrawl-Projekt eine andere Spielelogik hat (Spieler kontrollieren die Token nicht direkt usw.), dürften **TMX-Parser, Hex-Utility und Karten-Rendering** ausreichen. Die Spawn-/Objekt-Logik ist hingegen nicht ohne Weiteres übertragbar.

**Noch offen:** Eine Analyse des OpenBrawl-Repositories ist unbedingt nötig, um den tatsächlich benötigten Export-Umfang festzustellen.

### Entkopplung

**Frage:** Wie stark ist die Engine aktuell mit TiledWarfare-spezifischem Code (Widgets, Services, Assets) verwoben, und welche Refactorings sind nötig, um sie eigenständig nutzbar zu machen?

**Noch offen:** Festzustellen durch Analyse des Projekts.

### Wartung

**Frage:** Wo soll die Engine künftig gepflegt werden (mono-Repo, eigenes Repo) und wie werden Änderungen zwischen den Projekten synchronisiert?

**Entscheidung:** Die Engine soll hier gewartet werden. Jegliche Änderungen, die im OpenBrawl-Projekt Verwendung finden, sollen automatisch dort übernommen werden – daher die Idee mit dem Git-Submodul.

### Kompatibilität

**Frage:** Welche Flutter-/Dart-Versionen und Plattformen muss das Urban-Brawl-Projekt unterstützen?

**Entscheidung:** Dieselben Flutter-/Dart-Versionen und Plattformen, die dieses Projekt unterstützt.

## Was für Probleme können auftreten?

- **Versteckte Abhängigkeiten**: Die Engine nutzt u. U. interne Pfade, Assets oder Services (z. B. `rootBundle`, hardcodierte Bildpfade), die im Zielprojekt nicht vorhanden sind.
- **Versionskonflikte**: Unterschiedliche Flutter-/Dart-Versionen oder abweichende Abhängigkeiten (z. B. `package:xml`) zwischen den Projekten.
- **Lizenz- und Urheberfragen**: Klärung der Lizenz der Engine sowie der verwendeten Assets (Tilesets, Bilder).
- **Regressionsrisiko**: Änderungen für den Export dürfen das laufende TiledWarfare-Spiel nicht beschädigen – benötigt werden passende Tests und eine saubere Abstraktionsgrenze.
- **Doku-Lücke**: Fehlende oder veraltete Dokumentation der Engine erschwert die Einarbeitung im Zielprojekt.

## Links

- [OpenBrawl Repository](https://github.com/Reyneke/OpenBrawl)