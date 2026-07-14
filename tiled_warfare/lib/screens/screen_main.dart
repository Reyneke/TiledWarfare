import 'package:flutter/material.dart';
import 'package:tiled_warfare/models/match_record.dart';
import 'package:tiled_warfare/objects/object_player.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/screens/screen_battle_result.dart';
import 'package:tiled_warfare/theme/app_theme.dart';
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

class _ScreenMainState extends State<ScreenMain> with TickerProviderStateMixin {
  /// Die Pixel-Maße eines einzelnen Karten-Tiles (Breite).
  int _tileWidth = 32;

  /// Die Pixel-Maße eines einzelnen Karten-Tiles (Höhe).
  int _tileHeight = 32;

  /// Die Anzahl der Spalten der Karte.
  int _mapWidth = 30;

  /// Die Anzahl der Zeilen der Karte.
  int _mapHeight = 30;

  /// Der [TransformationController] des [InteractiveViewer] der Karte,
  /// der vom [WidgetMapLoader] bereitgestellt wird.
  TransformationController? _mapTransformationController;

  /// Die geparsten Spawnpunkte aus der Map.
  List<({String name, double x, double y})> _spawnPoints = [];

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
    setState(() {
      _tileWidth = tileWidth;
      _tileHeight = tileHeight;
      _mapWidth = mapWidth;
      _mapHeight = mapHeight;
    });
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

  /// Zeigt einen Bestätigungsdialog, bevor das Spiel vorzeitig beendet wird.
  /// Bei Bestätigung wird es als Sieg für den Host (Niederlage für den Spieler) gewertet.
  Future<bool> _confirmExit(BuildContext context) async {
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
  void _handleExitGame(BuildContext context) async {
    final confirmed = await _confirmExit(context);
    if (!confirmed || !context.mounted) return;
    
    if (context.mounted) {
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
  }

  /// Fokussiert die Kamera auf eine bestimmte Karten-Position (sanftes Scrollen).
  /// Zentriert die übergebene Karten-Position in der Mitte des Bildschirms.
  void _focusCameraOn(Offset mapPosition) {
    final controller = _mapTransformationController;
    if (controller == null) return;

    try {
      final screenSize = MediaQuery.of(context).size;
      // AppBar-Höhe abziehen
      final appBarHeight = kToolbarHeight;
      final availableHeight = screenSize.height - appBarHeight;

      // Aktuelle Zoom-Stufe ermitteln
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
      if ((currentTranslation - targetTranslation).distance > 50) {
        final animationController = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 300),
        );
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
            ..translate(value.dx, value.dy)
            ..scale(currentScale);
          controller.value = matrix;
        });

        animationController.forward();
      }
    } catch (_) {
      // Bei Fehlern ignorieren (z. B. wenn der Controller noch nicht bereit ist)
    }
  }

  /// Zentriert die Karte nach dem Laden in der Bildschirmmitte.
  void _centerMap() {
    final controller = _mapTransformationController;
    if (controller == null) return;

    try {
      final screenSize = MediaQuery.of(context).size;
      final appBarHeight = kToolbarHeight;
      final availableHeight = screenSize.height - appBarHeight;

      // Karten-Mitte in Pixeln berechnen
      final mapCenterX = (_mapWidth * _tileWidth + _tileWidth / 2) / 2;
      final mapCenterY = (_mapHeight * _tileHeight * 3 / 4 + _tileHeight / 4) / 2;

      // Passenden Zoom wählen, damit die gesamte Karte sichtbar ist
      final mapWidthPx = _mapWidth * _tileWidth + _tileWidth / 2;
      final mapHeightPx = _mapHeight * _tileHeight * 3 / 4 + _tileHeight / 4;
      final scaleX = screenSize.width / mapWidthPx;
      final scaleY = availableHeight / mapHeightPx;
      final scale = (scaleX < scaleY ? scaleX : scaleY).clamp(0.25, 1.5);

      // Matrix setzen: Kartenmitte zentrieren
      final translateX = screenSize.width / 2 - mapCenterX * scale;
      final translateY = availableHeight / 2 - mapCenterY * scale;

      final matrix = Matrix4.identity()
        ..translate(translateX, translateY)
        ..scale(scale);
      controller.value = matrix;
    } catch (_) {
      // Bei Fehlern ignorieren
    }
  }

  @override
  Widget build(BuildContext context) {
    // Zentriere die Karte nach dem ersten Build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerMap();
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleExitGame(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tiled Warfare'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Spiel beenden',
            onPressed: () => _handleExitGame(context),
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
        body: Stack(
          children: [
            // Karte im Hintergrund
            WidgetMapLoader(
              mapPath: widget.mapPath,
              onMapLoaded: _onMapLoaded,
              onTransformationControllerCreated:
                  _onTransformationControllerCreated,
              onSpawnPointsParsed: _onSpawnPointsParsed,
            ),
            // Token-Overlay im Vordergrund
            if (_mapTransformationController != null)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: false,
                  child: WidgetCaretaker(
                    tileWidth: _tileWidth,
                    tileHeight: _tileHeight,
                    mapWidth: _mapWidth,
                    mapHeight: _mapHeight,
                    transformationController: _mapTransformationController!,
                    spawnPoints: _spawnPoints,
                    onGameOver: _onGameOver,
                    onRequestCameraFocus: _focusCameraOn,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
