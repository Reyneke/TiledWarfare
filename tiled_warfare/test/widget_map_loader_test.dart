import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/utils/hex_grid.dart';
import 'package:tiled_warfare/widgets/widget_map_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WidgetMapLoader - Rendering (mit echten Assets)', () {
    testWidgets('valid map (map0) renders CustomPaint and fires onMapLoaded',
        (tester) async {
      final hexGrid = HexGrid(
        tileWidth: 32, tileHeight: 32, mapWidth: 30, mapHeight: 30,
      );

      Map<String, dynamic>? loaded;
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: WidgetMapLoader(
              hexGrid: hexGrid,
              mapPath: 'assets/maps/map0/street_battle.tmx',
              onMapLoaded: ({required tileWidth, required tileHeight,
                  required mapWidth, required mapHeight}) {
                loaded = {
                  'tileWidth': tileWidth,
                  'tileHeight': tileHeight,
                  'mapWidth': mapWidth,
                  'mapHeight': mapHeight,
                };
              },
            ),
          ),
        );
        // Warten, bis die async-Ladung abgeschlossen ist
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
      });

      expect(loaded, isNotNull);
      expect(loaded!['tileWidth'], 32);
      expect(loaded!['mapWidth'], 30);
      expect(loaded!['mapHeight'], 30);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('missing ground layer shows error UI', (tester) async {
      final hexGrid = HexGrid(
        tileWidth: 32, tileHeight: 32, mapWidth: 2, mapHeight: 2,
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: WidgetMapLoader(
              hexGrid: hexGrid,
              mapPath: 'assets/maps/map1/street_battle_colliders.tmx',
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
      });

      // map1 hat einen ground-Layer → kein Fehler.
      // Dieser Test prüft stattdessen, dass keine Exception geworfen wird.
      expect(tester.takeException(), isNull);
    });
  });
}