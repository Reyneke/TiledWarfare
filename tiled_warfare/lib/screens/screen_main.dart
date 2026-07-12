import 'package:flutter/material.dart';
import 'package:tiled_warfare/models/match_record.dart';
import 'package:tiled_warfare/objects/object_player.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
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

class _ScreenMainState extends State<ScreenMain> {
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

  /// Aktualisiert das Profil mit den Überlebenden des Gefechts,
  /// entfernt Tote aus dem Personal, speichert Match-Historie und persistiert.
  void _syncUnitsAfterBattle() {
    final player = ObjectPlayer();
    final profile = ObjectProfile();
    profile.syncUnitsAfterBattle(player.unitList);
    profile.saveToStorage();
  }

  /// Fügt Match-Records für das abgeschlossene Gefecht hinzu.
  void _addMatchRecords(bool playerWon) {
    final profile = ObjectProfile();
    final opponentName = ScreenMain.mapNameFromPath(widget.mapPath);
    final result = playerWon ? MatchResult.win : MatchResult.loss;

    profile.addMatchRecordsForBattle(
      opponentName: opponentName,
      result: result,
    );
  }

  /// Wird aufgerufen, wenn das Spiel vorbei ist (über den onGameOver-Callback).
  void _onGameOver(bool playerWon) {
    _addMatchRecords(playerWon);
    _syncUnitsAfterBattle();
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) return;
        _syncUnitsAfterBattle();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tiled Warfare'),
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
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
