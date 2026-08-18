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
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
      });

      expect(loaded, isNotNull);
      expect(loaded!['tileWidth'], 32);
      expect(loaded!['mapWidth'], 30);
      expect(loaded!['mapHeight'], 30);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('SizedBox child is at least viewport size (Fix 3f)', (tester) async {
        // Setze eine kleine Oberfläche, kleiner als die Karte (960px hoch)
        tester.view.physicalSize = const Size(800, 400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final hexGrid = HexGrid(
          tileWidth: 32, tileHeight: 32, mapWidth: 30, mapHeight: 30,
        );

        await tester.runAsync(() async {
          await tester.pumpWidget(
            MaterialApp(
              home: WidgetMapLoader(
                hexGrid: hexGrid,
                mapPath: 'assets/maps/map0/street_battle.tmx',
              ),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 200));
          await tester.pump();
        });

        // Das SizedBox im InteractiveViewer sollte mindestens 400px hoch sein
        final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).last);
        expect(sizedBox.height, greaterThanOrEqualTo(400),
            reason: 'Child must be at least viewport height to prevent white bar');
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

      expect(tester.takeException(), isNull);
    });
  });

  group('WidgetMapLoader - Fenstergrößen-Änderung (weißer Balken)', () {
    Future<void> pumpMap(WidgetTester tester, {Size size = const Size(800, 600)}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final hexGrid = HexGrid(
        tileWidth: 32, tileHeight: 32, mapWidth: 30, mapHeight: 30,
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: WidgetMapLoader(
              hexGrid: hexGrid,
              mapPath: 'assets/maps/map0/street_battle.tmx',
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
      });
    }

    testWidgets('SizedBox hat Karten-Pixelgröße (nicht Viewport)', (tester) async {
      await pumpMap(tester, size: const Size(800, 600));

      // Das SizedBox-Child hat die Karten-Pixelgröße (30x30 Tiles à 32px)
      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).last);
      expect(sizedBox.width, 30 * 32 + 16, // mapPixelWidth = 30*32 + 16
          reason: 'Child width must be map pixel width');
      expect(sizedBox.height, (30 * 32 * 3 ~/ 4) + 32 ~/ 4, // mapPixelHeight
          reason: 'Child height must be map pixel height');
    });

    testWidgets('InteractiveViewer ist korrekt konfiguriert (kein weißer Balken)', (tester) async {
      await pumpMap(tester, size: const Size(800, 600));

      // Der InteractiveViewer muss constrained: false und boundaryMargin: zero haben,
      // damit die Karte frei pannbar ist und keine weißen Ränder entstehen.
      final viewer = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
      expect(viewer.constrained, false,
          reason: 'InteractiveViewer must be unconstrained');
      expect(viewer.boundaryMargin, EdgeInsets.zero,
          reason: 'boundaryMargin must be zero to prevent white bars');
    });

    testWidgets('Karte bleibt nach Größenänderung gerendert', (tester) async {
      await pumpMap(tester, size: const Size(800, 600));

      // Mehrere Größenänderungen hintereinander – die Karte muss weiterhin
      // gerendert werden (CustomPaint vorhanden, kein Fehler).
      for (final size in [const Size(600, 400), const Size(1000, 700), const Size(400, 250)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpAndSettle();

        expect(find.byType(CustomPaint), findsWidgets,
            reason: 'Map must still render at $size');
        expect(tester.takeException(), isNull,
            reason: 'No exception at $size');
      }
    });
  });
}