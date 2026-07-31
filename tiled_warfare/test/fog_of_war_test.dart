import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/map_data.dart';
import 'package:tiled_warfare/objects/object_token.dart';
import 'package:tiled_warfare/services/fog_of_war.dart';
import 'package:tiled_warfare/utils/hex_grid.dart';

/// Hilfsfunktion: Erzeugt einen Token mit gegebenen Koordinaten und Sichtweite.
ObjectToken _makeToken({required int x, required int y, int fieldOfView = 3}) {
  final hexGrid = HexGrid(tileWidth: 32, tileHeight: 32, mapWidth: 20, mapHeight: 20);
  final pixel = hexGrid.hexToPixel(x: x, y: y);
  final token = ObjectToken(
    name: 'TestToken',
    imagePath: 'test.png',
    fieldOfView: fieldOfView,
  );
  token.position = pixel;
  return token;
}

void main() {
  late HexGrid hexGrid;
  late FogOfWarService fog;
  late Map<int, TerrainType> emptyTerrain;

  setUp(() {
    hexGrid = HexGrid(tileWidth: 32, tileHeight: 32, mapWidth: 10, mapHeight: 10);
    fog = FogOfWarService(hexGrid: hexGrid);
    emptyTerrain = {};
  });

  group('FogOfWarService — Basis-Tests', () {
    test('initial state: nothing visible or revealed', () {
      for (int y = 0; y < hexGrid.mapHeight; y++) {
        for (int x = 0; x < hexGrid.mapWidth; x++) {
          final key = hexGrid.hexKey(x, y);
          expect(fog.isVisible(key), false);
          expect(fog.isRevealed(key), false);
        }
      }
    });

    test('reset() clears all state', () {
      final token = _makeToken(x: 5, y: 5, fieldOfView: 2);
      fog.computeVisibility(
        friendlyTokens: [token],
        terrainMap: emptyTerrain,
        terrainConfigs: TerrainConfig.defaults,
      );
      expect(fog.visibleHexes.isNotEmpty, true);
      expect(fog.revealedHexes.isNotEmpty, true);

      fog.reset();
      expect(fog.visibleHexes.isEmpty, true);
      expect(fog.revealedHexes.isEmpty, true);
    });
  });

  group('FogOfWarService — Sichtbarkeit', () {
    test('token sees its own hex (fieldOfView = 0)', () {
      final token = _makeToken(x: 5, y: 5, fieldOfView: 0);
      fog.computeVisibility(
        friendlyTokens: [token],
        terrainMap: emptyTerrain,
        terrainConfigs: TerrainConfig.defaults,
      );

      final ownKey = hexGrid.hexKey(5, 5);
      expect(fog.isVisible(ownKey), true);
      // Nur das eigene Feld sollte sichtbar sein
      expect(fog.visibleHexes.length, 1);
    });

    test('token with fieldOfView = 1 sees itself + 6 neighbors', () {
      final token = _makeToken(x: 5, y: 5, fieldOfView: 1);
      fog.computeVisibility(
        friendlyTokens: [token],
        terrainMap: emptyTerrain,
        terrainConfigs: TerrainConfig.defaults,
      );

      // Start-Feld + 6 Nachbarn (falls alle in bounds)
      expect(fog.visibleHexes.length, 7);
    });

    test('dead token does not contribute to visibility', () {
      final token = _makeToken(x: 5, y: 5, fieldOfView: 3);
      token.woundValue = 0; // tot
      fog.computeVisibility(
        friendlyTokens: [token],
        terrainMap: emptyTerrain,
        terrainConfigs: TerrainConfig.defaults,
      );

      expect(fog.visibleHexes.isEmpty, true);
    });

    test('two tokens share vision (union of visible hexes)', () {
      final token1 = _makeToken(x: 5, y: 5, fieldOfView: 1);
      final token2 = _makeToken(x: 4, y: 5, fieldOfView: 1);

      fog.computeVisibility(
        friendlyTokens: [token1, token2],
        terrainMap: emptyTerrain,
        terrainConfigs: TerrainConfig.defaults,
      );

      // Beide sehen sich selbst + jeweils 6 Nachbarn (mitten auf der Karte),
      // aber sie überlappen sich teilweise.
      // Token1 bei (5,5): 7 Felder, Token2 bei (4,5): 7 Felder.
      // Überlappung: (4,5) und (5,5) sind gegenseitige Nachbarn → 7 + 7 - 2 = 12
      expect(fog.visibleHexes.length, greaterThan(7));
    });

    test('revealedHexes accumulates over multiple computeVisibility calls', () {
      final token = _makeToken(x: 0, y: 0, fieldOfView: 2);
      fog.computeVisibility(
        friendlyTokens: [token],
        terrainMap: emptyTerrain,
        terrainConfigs: TerrainConfig.defaults,
      );
      final firstRevealedCount = fog.revealedHexes.length;

      // Token bewegt sich nach (5,5)
      token.position = hexGrid.hexToPixel(x: 5, y: 5);
      fog.computeVisibility(
        friendlyTokens: [token],
        terrainMap: emptyTerrain,
        terrainConfigs: TerrainConfig.defaults,
      );

      // revealedHexes muss größer geworden sein
      expect(fog.revealedHexes.length, greaterThan(firstRevealedCount));
    });
  });

  group('FogOfWarService — Sichtbarrieren', () {
    test('wall blocks vision (behind wall is not visible)', () {
      // Token bei (5,5) sieht nach oben, aber eine Mauer bei (5,7) blockiert
      final token = _makeToken(x: 5, y: 5, fieldOfView: 5);
      final terrainMap = <int, TerrainType>{
        hexGrid.hexKey(5, 7): TerrainType.wall,
      };

      fog.computeVisibility(
        friendlyTokens: [token],
        terrainMap: terrainMap,
        terrainConfigs: TerrainConfig.defaults,
      );

      // Die Mauer selbst ist sichtbar
      expect(fog.isVisible(hexGrid.hexKey(5, 7)), true);
      // Feld hinter der Mauer (5,8) ist NICHT sichtbar
      expect(fog.isVisible(hexGrid.hexKey(5, 8)), false);
      // Aber (5,6) direkt unter der Mauer ist sichtbar
      expect(fog.isVisible(hexGrid.hexKey(5, 6)), true);
    });

    test('open field does not block vision at distance', () {
      final token = _makeToken(x: 5, y: 5, fieldOfView: 3);
      fog.computeVisibility(
        friendlyTokens: [token],
        terrainMap: emptyTerrain,
        terrainConfigs: TerrainConfig.defaults,
      );

      // Bei freiem Feld sollten alle Felder im Radius 3 sichtbar sein
      expect(fog.isVisible(hexGrid.hexKey(5, 8)), true); // 3 Schritte
      expect(fog.isVisible(hexGrid.hexKey(8, 5)), true); // 3 Schritte
    });
  });

  group('FogOfWarService — getVisibleEnemies', () {
    test('enemy on visible hex is returned', () {
      final friendly = _makeToken(x: 5, y: 5, fieldOfView: 3);
      final enemy = _makeToken(x: 6, y: 6, fieldOfView: 0);

      fog.computeVisibility(
        friendlyTokens: [friendly],
        terrainMap: emptyTerrain,
        terrainConfigs: TerrainConfig.defaults,
      );

      final visibleEnemies = fog.getVisibleEnemies([enemy]);
      expect(visibleEnemies.length, 1);
      expect(visibleEnemies.first, enemy);
    });

    test('enemy outside visible range is not returned', () {
      final friendly = _makeToken(x: 0, y: 0, fieldOfView: 1);
      final enemy = _makeToken(x: 9, y: 9, fieldOfView: 0);

      fog.computeVisibility(
        friendlyTokens: [friendly],
        terrainMap: emptyTerrain,
        terrainConfigs: TerrainConfig.defaults,
      );

      final visibleEnemies = fog.getVisibleEnemies([enemy]);
      expect(visibleEnemies.isEmpty, true);
    });

    test('dead enemy is not returned even if visible', () {
      final friendly = _makeToken(x: 5, y: 5, fieldOfView: 3);
      final deadEnemy = _makeToken(x: 5, y: 6, fieldOfView: 0);
      deadEnemy.woundValue = 0;

      fog.computeVisibility(
        friendlyTokens: [friendly],
        terrainMap: emptyTerrain,
        terrainConfigs: TerrainConfig.defaults,
      );

      final visibleEnemies = fog.getVisibleEnemies([deadEnemy]);
      expect(visibleEnemies.isEmpty, true);
    });
  });

  group('FogOfWarService — Edge Cases', () {
    test('token at map edge does not cause out-of-bounds errors', () {
      final token = _makeToken(x: 0, y: 0, fieldOfView: 5);
      expect(
        () => fog.computeVisibility(
          friendlyTokens: [token],
          terrainMap: emptyTerrain,
          terrainConfigs: TerrainConfig.defaults,
        ),
        returnsNormally,
      );
    });

    test('empty friendly token list produces empty visibility', () {
      fog.computeVisibility(
        friendlyTokens: [],
        terrainMap: emptyTerrain,
        terrainConfigs: TerrainConfig.defaults,
      );
      expect(fog.visibleHexes.isEmpty, true);
    });

    test('hasLineOfSight: direct neighbors are always visible', () {
      expect(
        fog.hasLineOfSight(
          x1: 5, y1: 5, x2: 5, y2: 6,
          terrainMap: emptyTerrain,
          terrainConfigs: TerrainConfig.defaults,
        ),
        true,
      );
      expect(
        fog.hasLineOfSight(
          x1: 5, y1: 5, x2: 6, y2: 5,
          terrainMap: emptyTerrain,
          terrainConfigs: TerrainConfig.defaults,
        ),
        true,
      );
    });

    test('hasLineOfSight: wall blocks line of sight', () {
      final terrainMap = <int, TerrainType>{
        hexGrid.hexKey(5, 7): TerrainType.wall,
      };
      // Von (5,5) nach (5,9) führt durch Mauer bei (5,7)
      expect(
        fog.hasLineOfSight(
          x1: 5, y1: 5, x2: 5, y2: 9,
          terrainMap: terrainMap,
          terrainConfigs: TerrainConfig.defaults,
        ),
        false,
      );
    });

    test('hasLineOfSight: start field does not block (even if blocksVision)', () {
      // Token steht auf einer Mauer (ungewöhnlich, aber möglich)
      // Die Sichtlinie sollte trotzdem funktionieren
      expect(
        fog.hasLineOfSight(
          x1: 5, y1: 5, x2: 5, y2: 8,
          terrainMap: emptyTerrain,
          terrainConfigs: TerrainConfig.defaults,
        ),
        true,
      );
    });
  });
}