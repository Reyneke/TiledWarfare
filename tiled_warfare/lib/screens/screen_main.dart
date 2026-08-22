import 'package:flutter/material.dart';
import 'package:tiled_warfare/models/map_data.dart';
import 'package:tiled_warfare/models/sector.dart';
import 'package:tiled_warfare/objects/object_host.dart';
import 'package:tiled_warfare/screens/screen_battle_result.dart';
import 'package:tiled_warfare/services/fog_of_war.dart';
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
  HexGrid? _hexGrid;
  TransformationController? _mapTransformationController;
  List<({String name, double x, double y})> _spawnPoints = [];
  Set<int> _collisionSet = {};
  bool _mapCentered = false;
  bool _mapDataReady = false;
  AnimationController? _focusAnimationController;

  /// Fog-of-War-Service für Sichtbarkeits-Berechnung und -Darstellung.
  FogOfWarService? _fogOfWarService;

  /// Gelände-Map für die Fog-of-War-Berechnung (hexKey → TerrainType).
  Map<int, TerrainType>? _terrainMap;

  /// Die geparsten Sektoren aus der "Sektoren"-Objektebene der Karte.
  List<Sector> _sectors = const [];

  /// Letzte Layout-Constraints des [LayoutBuilder] (verfügbarer Platz für
  /// die Karte). Wird für die Zentrierung verwendet, damit der weiße Balken
  /// unten nicht entsteht.
  BoxConstraints? _lastConstraints;

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

  /// Wird bei Fenster-Größenänderungen aufgerufen.
  /// Erzwingt LayoutBuilder-Neubau (setState) und setzt dann die
  /// Transformation zurück, damit die Karte zentriert bleibt.
  @override
  void didChangeMetrics() {
    if (!_mapDataReady || _hexGrid == null) return;

    // setState erzwingt LayoutBuilder-Neubau → aktualisiert _lastConstraints
    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Karte zurücksetzen: verhindert weiße Balken durch veraltete
      // Transformation nach Fenstergrößen-Änderung
      _centerMap();
    });
  }

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

  void _onMapLoaded({
    required int tileWidth,
    required int tileHeight,
    required int mapWidth,
    required int mapHeight,
  }) {
    final hexGrid = HexGrid(
      tileWidth: tileWidth,
      tileHeight: tileHeight,
      mapWidth: mapWidth,
      mapHeight: mapHeight,
    );

    ObjectHost().hexGrid = hexGrid;

    // Fog of War Service initialisieren
    _fogOfWarService = FogOfWarService(hexGrid: hexGrid);
    ObjectHost().setFogOfWarService(_fogOfWarService!);

    setState(() {
      _hexGrid = hexGrid;
      _mapDataReady = true;
      _mapCentered = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerMap());
  }

  void _onTransformationControllerCreated(TransformationController controller) {
    _mapTransformationController = controller;
  }

  void _onSpawnPointsParsed(List<({String name, double x, double y})> spawnPoints) {
    setState(() {
      _spawnPoints = spawnPoints;
    });
  }

  void _onTerrainParsed(Map<int, TerrainType> terrainMap, Set<int> collisionSet) {
    ObjectHost().collisionSet = collisionSet;
    _terrainMap = terrainMap;

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

  /// Übernimmt die geparsten Sektoren aus der "Sektoren"-Objektebene.
  void _onSectorsParsed(List<Sector> sectors) {
    setState(() {
      _sectors = sectors;
    });
  }

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

  void _focusCameraOn(Offset mapPosition) {
    final controller = _mapTransformationController;
    if (controller == null) return;

    final screenSize = MediaQuery.of(context).size;
    final availableHeight =
        _lastConstraints?.maxHeight ?? screenSize.height - kToolbarHeight;

    // Linker Rand für das Info-Panel (muss mit dem Padding der Karte
    // übereinstimmen, damit die Kamera im sichtbaren Kartenbereich zentriert).
    const leftPanelWidth = 240.0;
    final viewportWidth = screenSize.width - leftPanelWidth;

    final currentScale = controller.value.getMaxScaleOnAxis();
    if (currentScale <= 0) return;

    final targetDx = viewportWidth / 2 - mapPosition.dx * currentScale;
    final targetDy = availableHeight / 2 - mapPosition.dy * currentScale;

    final currentTranslation = Offset(
      controller.value.getTranslation().x,
      controller.value.getTranslation().y,
    );
    final targetTranslation = Offset(targetDx, targetDy);

    if ((currentTranslation - targetTranslation).distance <= 50) return;

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
        ..scaleByDouble(currentScale, currentScale, currentScale, 1.0);
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

  /// Setzt die initiale Karten-Transformation.
  ///
  /// Der [InteractiveViewer] (mit `alignment: Alignment.topLeft`) steuert
  /// das Panning/Zoomen eigenständig. Eine initiale Translation/Skalierung
  /// würde mit dem InteractiveViewer konkurrieren und weiße Balken erzeugen.
  /// Daher wird [Matrix4.identity] gesetzt – die Karte beginnt oben-links
  /// im Viewport und wird vom InteractiveViewer korrekt dargestellt.
  void _centerMap() {
    final controller = _mapTransformationController;
    if (controller == null) return;

    if (_hexGrid == null) return;

    // Keine manuelle Zentrierung – der InteractiveViewer übernimmt das.
    // Matrix4.identity() = Karte bei (0,0) ohne Skalierung.
    controller.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
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
          builder: (context, constraints) {
            // Aktuelle Constraints speichern (für korrekte Zentrierung bei
            // Fenster-Größenänderungen)
            _lastConstraints = constraints;
            // clipBehavior: Clip.none – erlaubt, dass das Info-Panel (das im
            // gepaddeten WidgetCaretaker bei left: -232 sitzt) in die linke
            // Gutter-Spalte ragen kann. Mit Clip.hardEdge würde das Panel
            // am Rand des gepaddeten Bereichs abgeschnitten.
            return Stack(
              clipBehavior: Clip.none,
              children: [
                const SizedBox.expand(),
                // Linker Rand als Platzhalter für das Info-Panel (CombatActions).
                // Verhindert, dass Tokens, die links spawnen, unter der
                // Dialogbox des Spielers verschwinden.
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 240),
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
                      onSectorsParsed: _onSectorsParsed,
                      fogOfWarService: _fogOfWarService,
                    ),
                  ),
                ),
                // Der WidgetCaretaker erhält die volle Fläche (KEIN
                // Padding(left: 240)). Die Karte/Tokens werden intern um
                // 240px nach rechts gepaddet (linke Gutter-Spalte für das
                // Info-Panel), sodass Karte und Tokens weiterhin ab x=240
                // liegen. Die UI-Panels (Info, Status) liegen im äußeren
                // Stock des WidgetCaretaker bei left: 8 / right: 8 –
                // innerhalb der Stack-Bounds und damit klickbar.
                // (Bugfix: "Combat Maneuvers Buttons funktionieren nicht" –
                // vorher lagen die Panels bei left: -232 außerhalb der
                // Stack-Bounds des gepaddeten WidgetCaretaker; RenderBox.hitTest
                // lehnt Positionen außerhalb der Bounds ab, unabhängig von
                // clipBehavior: Clip.none.)
                if (_mapTransformationController != null && _mapDataReady && _hexGrid != null)
                  Positioned.fill(
                    child: WidgetCaretaker(
                      hexGrid: _hexGrid!,
                      transformationController: _mapTransformationController!,
                      spawnPoints: _spawnPoints,
                      collisionSet: _collisionSet,
                      onGameOver: _onGameOver,
                      onRequestCameraFocus: _focusCameraOn,
                      fogOfWarService: _fogOfWarService,
                      terrainMap: _terrainMap,
                      sectors: _sectors,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/*Der Rundenzähler, der auch u.A. auch "Zug beenden" beeinhaltet, sowie der rechte Rand der Map ist von der sichtbaren 
Breite her schmaler in der Ansicht, als der WidgetCaretaker. Siehe "2026-07-18 (5).png" Warum?*/