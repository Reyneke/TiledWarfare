import 'package:flutter/material.dart';
import 'package:tiled_warfare/models/map_data.dart';
import 'package:tiled_warfare/objects/object_host.dart';
import 'package:tiled_warfare/screens/screen_battle_result.dart';
import 'package:tiled_warfare/services/terrain_service.dart';
import 'package:tiled_warfare/theme/app_theme.dart';
import 'package:tiled_warfare/utils/hex_grid.dart';
import 'package:tiled_warfare/widgets/widget_caretaker.dart';
import 'package:tiled_warfare/widgets/widget_map_loader.dart';

class ScreenMain extends StatefulWidget {
  /// Pfad zur .tmx-Datei, die geladen werden soll.
  final String mapPath;

  const ScreenMain({super.key, this.mapPath = 'assets/maps/street_battle.tmx'});

  /// Extrahiert den Kartennamen aus dem Pfad für die Match-Historie.
  static String mapNameFromPath(String path) {
    // Z. B. "assets/maps/map0/street_battle.tmx" → "Street Battle"
    final filename = path.split('/').last.replaceAll('.tmx', '');
    return filename
        .split('_')
        .map((word) =>
            word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
        .join(' ');
  }

  @override
  State<ScreenMain> createState() => _ScreenMainState();
}

class _ScreenMainState extends State<ScreenMain>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  /// Die zentrale Hex-Utility-Instanz für alle Gitter-Berechnungen.
  /// Wird erstellt, sobald die Kartendaten geladen sind.
  HexGrid? _hexGrid;

  /// Der [TransformationController] des [InteractiveViewer] der Karte,
  /// der vom [WidgetMapLoader] bereitgestellt wird.
  TransformationController? _mapTransformationController;

  /// Die geparsten Spawnpunkte aus der Map.
  List<({String name, double x, double y})> _spawnPoints = [];

  /// Menge blockierter Hex-Felder aus dem Kollisions-Layer der geladenen Karte.
  Set<int> _collisionSet = {};

  /// Flag, ob die Karte bereits einmal zentriert wurde.
  /// Verhindert, dass _centerMap() bei jedem Build erneut aufgerufen wird
  /// (was die Benutzer-Interaktion mit der Karte stören würde).
  bool _mapCentered = false;

  /// Flag, ob die Karte tatsächlich geladen wurde (Daten von WidgetMapLoader
  /// empfangen). Verhindert, dass _centerMap() vor dem ersten Map-Load mit
  /// den Default-Werten (30×30, 32×32) läuft.
  bool _mapDataReady = false;

  /// Aktueller Kamera-Fokus-AnimationController, der bei jedem
  /// Aufruf von [_focusCameraOn] neu erstellt wird. Muss disposed
  /// werden, um Memory Leaks zu vermeiden.
  AnimationController? _focusAnimationController;

  /// Letzte bekannte Bildschirmgröße. Wird verwendet, um unnötige
  /// Neu-Zentrierungen bei unwesentlichen Größenänderungen zu vermeiden.
  Size? _lastScreenSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusAnimationController?.dispose();
    super.dispose();
  }

  /// Wird bei Fenster-Größenänderungen (z.B. Maximieren/Ziehen) aufgerufen.
  /// Zentriert die Karte neu, wenn sich die Fenstergröße wesentlich geändert hat,
  /// damit die Karte nicht abgeschnitten wird (Bugfix: "Unterer Teil der Karte
  /// wird nicht gezeichnet, wenn Fenster größer wird").
  @override
  void didChangeMetrics() {
    if (_mapDataReady && _hexGrid != null) {
      // Kurze Verzögerung, damit MediaQuery.of(context) die neue Größe hat
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Prüfen, ob sich die Größe relevant geändert hat (mehr als 20px)
          final newSize = MediaQuery.of(context).size;
          if (_lastScreenSize != null) {
            final deltaH = (newSize.height - _lastScreenSize!.height).abs();
            final deltaW = (newSize.width - _lastScreenSize!.width).abs();
            if (deltaH < 20 && deltaW < 20) return;
          }
          _lastScreenSize = newSize;
          // Nur bei nicht-triviale Zoomstufe neu zentrieren
          // (bei Scale > 1.1 hat der Benutzer manuell gezoomt, dann nicht stören)
          final controller = _mapTransformationController;
          if (controller != null) {
            final scale = controller.value.getMaxScaleOnAxis();
            final baseScale = _computeFitToScreenScale();
            // Nur neu zentrieren, wenn der Zoom nahe an der "Fit-to-Screen"-Skala liegt
            if ((scale - baseScale).abs() < 0.15) {
              _centerMap();
            }
          }
        }
      });
    }
  }

  /// Berechnet die Skalierung, die nötig ist, damit die Karte auf den Bildschirm passt.
  double _computeFitToScreenScale() {
    if (_hexGrid == null) return 1.0;
    final screenSize = MediaQuery.of(context).size;
    final availableHeight = screenSize.height - kToolbarHeight;
    final scaleX = screenSize.width / _hexGrid!.mapPixelWidth;
    final scaleY = availableHeight / _hexGrid!.mapPixelHeight;
    return (scaleX < scaleY ? scaleX : scaleY).clamp(0.25, 1.5);
  }

  /// Wird aufgerufen, wenn das Spiel vorbei ist (über den onGameOver-Callback).
  /// Navigiert zum Ergebnis-Bildschirm, der XP verteilt und speichert.
  void _onGameOver(bool playerWon) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ScreenBattleResult(
          playerWon: playerWon,
          opponentName: ScreenMain.mapNameFromPath(widget.mapPath),
        ),
      ),
    );
  }

  /// Wird vom [WidgetMapLoader] aufgerufen, sobald die Karte geladen wurde,
  /// um die Kartendimensionen an den [WidgetCaretaker] weiterzugeben.
  void _onMapLoaded({
    required int tileWidth,
    required int tileHeight,
    required int mapWidth,
    required int mapHeight,
  }) {
    // HexGrid-Instanz erstellen und an alle Konsumenten weitergeben
    final hexGrid = HexGrid(
      tileWidth: tileWidth,
      tileHeight: tileHeight,
      mapWidth: mapWidth,
      mapHeight: mapHeight,
    );
    
    // HexGrid an den ObjectHost-Singleton übergeben
    ObjectHost().hexGrid = hexGrid;
    
    setState(() {
      _hexGrid = hexGrid;
      // Karten-Daten sind jetzt bereit
      _mapDataReady = true;
      // Zentriere die Karte im ersten Frame (nicht erst NACH dem ersten
      // Frame). Der alte Ansatz mit addPostFrameCallback in build() erzeugte
      // einen sichtbaren Frame, in dem die Karte unzentriert am linken Rand
      // klebte (Bugfix: "Inhalt drängt sich an den linken Rand").
      // _mapCentered wird hier bereits auf true gesetzt, damit build()
      // keinen weiteren PostFrameCallback hinzufügt.
      _mapCentered = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerMap());
  }

  /// Wird vom [WidgetMapLoader] aufgerufen, sobald der
  /// [TransformationController] erstellt wurde.
  void _onTransformationControllerCreated(TransformationController controller) {
    _mapTransformationController = controller;
  }

  /// Wird vom [WidgetMapLoader] aufgerufen, sobald die Spawnpunkte aus der
  /// Map geparst wurden.
  void _onSpawnPointsParsed(List<({String name, double x, double y})> spawnPoints) {
    setState(() {
      _spawnPoints = spawnPoints;
    });
  }

  /// Wird vom [WidgetMapLoader] aufgerufen, sobald Terrain- und
  /// Kollisionsdaten aus der Map geparst wurden.
  void _onTerrainParsed(Map<int, TerrainType> terrainMap, Set<int> collisionSet) {
    // Kollisionsdaten auch an den ObjectHost weitergeben,
    // damit Host-Tokens (Zombies) nicht durch Wände laufen können.
    ObjectHost().collisionSet = collisionSet;

    // TerrainService erstellen und an den ObjectHost übergeben,
    // damit Zombies Geländekosten bei der Bewegung berücksichtigen.
    if (_hexGrid != null) {
      ObjectHost().setTerrainService(TerrainService(
        terrainMap: terrainMap,
        configs: TerrainConfig.defaults,
        collisionSet: collisionSet,
        hexGrid: _hexGrid!,
      ));
    }

    setState(() {
      _collisionSet = collisionSet;
    });
  }

  /// Zeigt einen Bestätigungsdialog, bevor das Spiel vorzeitig beendet wird.
  /// Bei Bestätigung wird es als Sieg für den Host (Niederlage für den Spieler) gewertet.
  Future<bool> _confirmExit() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Spiel beenden?'),
        content: const Text('Möchtest du das Spiel wirklich vorzeitig beenden?\n'
            'Dies wird als Niederlage für dich gewertet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Beenden'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Behandelt das vorzeitige Verlassen des Spiels (Back-Button).
  /// Zeigt einen Bestätigungsdialog und wertet es als Niederlage für den Spieler.
  Future<void> _handleExitGame() async {
    final confirmed = await _confirmExit();
    if (!confirmed || !mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ScreenBattleResult(
          playerWon: false,
          opponentName: ScreenMain.mapNameFromPath(widget.mapPath),
        ),
      ),
    );
  }

  /// Fokussiert die Kamera auf eine bestimmte Karten-Position (sanftes Scrollen).
  /// Zentriert die übergebene Karten-Position in der Mitte des Bildschirms.
  ///
  /// Vorherige Animation-Controller werden korrekt disposed, um Memory Leaks
  /// zu vermeiden.
  void _focusCameraOn(Offset mapPosition) {
    final controller = _mapTransformationController;
    if (controller == null) return;

    final screenSize = MediaQuery.of(context).size;
    final appBarHeight = kToolbarHeight;
    final availableHeight = screenSize.height - appBarHeight;

    final currentScale = controller.value.getMaxScaleOnAxis();
    if (currentScale <= 0) return;

    // Ziel-Position in Bildschirm-Koordinaten umrechnen:
    // Bildschirmmitte = (screenSize.width / 2, availableHeight / 2)
    // Wir müssen die Matrix so setzen, dass mapPosition auf die Bildschirmmitte fällt
    final targetDx = screenSize.width / 2 - mapPosition.dx * currentScale;
    final targetDy = availableHeight / 2 - mapPosition.dy * currentScale;

    // Sanfte Animation zur Ziel-Position
    final currentTranslation = Offset(
      controller.value.getTranslation().x,
      controller.value.getTranslation().y,
    );
    final targetTranslation = Offset(targetDx, targetDy);

    // Nur animieren, wenn die Entfernung signifikant ist (> 50 Pixel)
    if ((currentTranslation - targetTranslation).distance <= 50) return;

    // Vorherigen AnimationController disposten, um Memory Leaks zu vermeiden
    _focusAnimationController?.dispose();

    final animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _focusAnimationController = animationController;

    final animation = Tween<Offset>(
      begin: currentTranslation,
      end: targetTranslation,
    ).animate(CurvedAnimation(
      parent: animationController,
      curve: Curves.easeInOut,
    ));

    animation.addListener(() {
      final value = animation.value;
      final matrix = Matrix4.identity()
        ..setTranslationRaw(value.dx, value.dy, 0)
        ..scale(currentScale);
      controller.value = matrix;
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        animationController.dispose();
        if (_focusAnimationController == animationController) {
          _focusAnimationController = null;
        }
      }
    });

    animationController.forward();
  }

  /// Zentriert die Karte nach dem Laden in der Bildschirmmitte.
  void _centerMap() {
    final controller = _mapTransformationController;
    final hexGrid = _hexGrid;
    if (controller == null || hexGrid == null) return;

    final screenSize = MediaQuery.of(context).size;
    final appBarHeight = kToolbarHeight;
    final availableHeight = screenSize.height - appBarHeight;

    // Karten-Mitte in Pixeln berechnen (mittels HexGrid)
    final mapCenterY = hexGrid.mapPixelHeight / 2;

    // Passenden Zoom wählen, damit die gesamte Karte sichtbar ist
    final mapWidthPx = hexGrid.mapPixelWidth;
    final mapHeightPx = hexGrid.mapPixelHeight;
    final scaleX = screenSize.width / mapWidthPx;
    final scaleY = availableHeight / mapHeightPx;
    final scale = (scaleX < scaleY ? scaleX : scaleY).clamp(0.25, 1.5);

    // Matrix setzen: Karte linksbündig ausrichten
    // translateX = 0 → Karte beginnt am linken Bildschirmrand
    // Vertikal bleibt die Karte zentriert
    final translateX = 0.0;
    final translateY = availableHeight / 2 - mapCenterY * scale;

    final matrix = Matrix4.identity()
      ..setTranslationRaw(translateX, translateY, 0)
      ..scale(scale);
    controller.value = matrix;
  }

  @override
  Widget build(BuildContext context) {
    // Zentriere die Karte NUR wenn die Karte geladen ist und noch nicht
    // zentriert wurde. Das _mapCentered-Flag verhindert, dass _centerMap()
    // bei jedem setState() erneut aufgerufen wird, was die Benutzer-
    // Interaktion (Scrollen/Zoomen) stören würde.
    // Wichtig: Warte auf _mapDataReady, damit _centerMap() nicht mit den
    // Default-Dimensionen (30×30, 32×32) läuft, bevor die tatsächlichen
    // Kartendaten vom WidgetMapLoader geladen wurden.
    if (_mapDataReady && !_mapCentered) {
      _mapCentered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _centerMap());
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleExitGame();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tiled Warfare'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Spiel beenden',
            onPressed: _handleExitGame,
          ),
          actions: [
            ValueListenableBuilder<ThemeMode>(
              valueListenable: AppTheme.themeModeNotifier,
              builder: (context, themeMode, child) {
                return IconButton(
                  icon: Icon(
                    themeMode == ThemeMode.dark
                        ? Icons.light_mode
                        : Icons.dark_mode,
                  ),
                  tooltip: themeMode == ThemeMode.dark
                      ? 'Switch to Light Theme'
                      : 'Switch to Dark Theme',
                  onPressed: () {
                    AppTheme.themeModeNotifier.value =
                        themeMode == ThemeMode.dark
                            ? ThemeMode.light
                            : ThemeMode.dark;
                  },
                );
              },
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) => Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // SizedBox.expand() als nicht-positioniertes Child, das den Stack
              // auf die volle verfügbare Größe zwingt. Ohne dies sized sich der
              // Stack auf die Kartenmaße (~976×728px), nicht auf die Fensterbreite,
              // was einen Spalt zwischen Stack-rechts und Fensterrand verursacht.
              // (Bugfix: "Spalt zwischen Stack und rechtem Fensterrand")
              const SizedBox.expand(),
              // Karte im Hintergrund – als Positioned.fill, damit der Stack
              // nicht auf Kartenmaße geschrumpft wird (Bugfix: Spalt rechts)
              Positioned.fill(
                child: WidgetMapLoader(
                  hexGrid: _hexGrid ?? const HexGrid(
                    tileWidth: 32,
                    tileHeight: 32,
                    mapWidth: 30,
                    mapHeight: 30,
                  ),
                  mapPath: widget.mapPath,
                  onMapLoaded: _onMapLoaded,
                  onTransformationControllerCreated:
                      _onTransformationControllerCreated,
                  onSpawnPointsParsed: _onSpawnPointsParsed,
                  onTerrainParsed: _onTerrainParsed,
                ),
              ),
              // Token-Overlay im Vordergrund (erst anzeigen, wenn Karte geladen ist)
              if (_mapTransformationController != null && _mapDataReady && _hexGrid != null)
                Positioned.fill(
                  child: WidgetCaretaker(
                    hexGrid: _hexGrid!,
                    transformationController: _mapTransformationController!,
                    spawnPoints: _spawnPoints,
                    collisionSet: _collisionSet,
                    onGameOver: _onGameOver,
                    onRequestCameraFocus: _focusCameraOn,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/*Der Rundenzähler, der auch u.A. auch "Zug beenden" beeinhaltet, sowie der rechte Rand der Map ist von der sichtbaren 
Breite her schmaler in der Ansicht, als der WidgetCaretaker. Siehe "2026-07-18 (5).png" Warum?*/