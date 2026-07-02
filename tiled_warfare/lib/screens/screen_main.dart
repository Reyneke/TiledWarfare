import 'package:flutter/material.dart';
import 'package:tiled_warfare/theme/app_theme.dart';
import 'package:tiled_warfare/widgets/widget_caretaker.dart';
import 'package:tiled_warfare/widgets/widget_map_loader.dart';

class ScreenMain extends StatefulWidget {
  const ScreenMain({super.key});

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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            onMapLoaded: _onMapLoaded,
            onTransformationControllerCreated:
                _onTransformationControllerCreated,
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
                ),
              ),
            ),
        ],
      ),

    );
  }
}
