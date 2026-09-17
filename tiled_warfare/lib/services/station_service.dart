import 'package:tiled_warfare/models/stations.dart';
import 'package:tiled_warfare/objects/player_objects/object_apprentice.dart';
import 'package:tiled_warfare/services/economy_service.dart';
import 'package:tiled_warfare/utils/hex_grid.dart';

/// Stations-Auren im Gefecht (Karrierepfade, V10 – Phase 4).
///
/// Eine Station wirkt **selbst** (Getter auf `ObjectApprentice`) und
/// **zusätzlich als Aura** auf verbündete Einheiten innerhalb
/// `EconomyBalance.stationAuraRadiusByRank[rang]` Hexfeldern. Die Selbstwirkung
/// ist ein reiner Prozentwert; die Aura wird hier als **transienter** Bonus auf
/// den Verbündeten gebucht (kein Persistenzwert, vgl. `timesAttackedThisTurn`).
///
/// Die Berechnung ist bewusst als reine, widget-freie Funktion ausgelegt, damit
/// sie ohne Karten-Rendering testbar bleibt: Der Aufrufer liefert die
/// Hex-Koordinaten je Einheit über [hexOf].
class StationService {
  StationService._();

  /// Setzt die transienten Aura-Boni aller [allies] neu (idempotent).
  ///
  /// Muss vor jedem Angriff aufgerufen werden, damit Bewegung und
  /// Rundenwechsel korrekt berücksichtigt sind. Support-Stationen
  /// (z. B. `Pâtissier`) verteilen keine Kampf-Aura.
  static void applyStationAuras({
    required Iterable<ObjectApprentice> allies,
    required HexGrid grid,
    required ({int x, int y}) Function(ObjectApprentice) hexOf,
  }) {
    final units = allies.toList(growable: false);

    // 1. Alles zurücksetzen – die Aura wird immer frisch hergeleitet.
    for (final unit in units) {
      unit.stationAuraAttack = 0;
      unit.stationAuraDefense = 0;
      unit.stationAuraDamage = 0;
    }

    // 2. Je Aura-Quelle die Verbündeten im Radius buffen.
    for (final source in units) {
      if (!EconomyService.isStationRank(source.rank)) continue;
      final station = source.station;
      if (!EconomyService.isValidStation(station)) continue;
      if (EconomyService.isSupportStation(station)) continue;
      final radius = EconomyService.stationAuraRadius(source.rank);
      if (radius <= 0) continue;

      final sourceHex = hexOf(source);
      for (final target in units) {
        // Die Selbstwirkung läuft bereits über die Stations-Getter.
        if (identical(target, source)) continue;
        final targetHex = hexOf(target);
        final distance = grid.distance(
          x1: sourceHex.x,
          y1: sourceHex.y,
          x2: targetHex.x,
          y2: targetHex.y,
        );
        if (distance > radius) continue;

        target.stationAuraAttack += _percentOf(
          target.attackValue,
          EconomyService.stationAuraPercent(station, StationStat.attack),
        );
        target.stationAuraDefense += _percentOf(
          target.defenseValue,
          EconomyService.stationAuraPercent(station, StationStat.defense),
        );
        target.stationAuraDamage += _percentOf(
          target.damageValue,
          EconomyService.stationAuraPercent(station, StationStat.damage),
        );
      }
    }
  }

  /// Anteiliger Betrag von [base] für [percent] (gerundet, 0 = unverändert).
  static int _percentOf(int base, int percent) =>
      percent == 0 ? 0 : (base * percent / 100).round();
}
