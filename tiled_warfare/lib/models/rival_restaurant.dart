import 'package:flutter/foundation.dart';

/// Ein **Rivalen-Restaurant** (NPC-Konkurrent im Stadtteil, Kapitel 13).
///
/// Das Minimal-Modul (V11, `13_Gegner_Restaurants.md`) führt Rivalen als
/// **deterministisch abgeleiteten** Zustand: ID, Name, Stadtteil und
/// Grund-Prestige folgen rein aus Stadtteil und Rivalen-Index (kein Zufall im
/// Catch-up, V8-Idempotenz). Der einzige **veränderliche** Anteil ist ein
/// befristeter Sabotage-Malus, der als Fenster am Restaurant des Spielers
/// persistiert wird (`RestaurantData.sabotageTargetId`/`sabotageAppliedUntil`)
/// – nicht am Rivalen selbst.
@immutable
class RivalRestaurant {
  /// Stabile ID (CRC32 aus Stadtteil + Rivalen-Index).
  final int id;

  /// Anzeigename (Namensgenerator, `random_name_generator`).
  final String name;

  /// Stadtteil, in dem der Rivale konkurriert.
  final String district;

  /// Persönlichkeits-Profil (deterministisch aus der Rivalen-ID, V9).
  final int personalityId;

  /// Grund-Prestige aus dem Stadtteil (`EconomyBalance.districtPrestigeFor`).
  final double basePrestige;

  const RivalRestaurant({
    required this.id,
    required this.name,
    required this.district,
    required this.personalityId,
    required this.basePrestige,
  });

  /// `true`, wenn dieser Rivale zum Zeitpunkt [now] sabotiert ist.
  bool isSabotagedAt(int? sabotagedId, DateTime? sabotagedUntil,
          DateTime now) =>
      sabotagedId == id && sabotagedUntil != null && now.isBefore(sabotagedUntil);

  /// Prestige im sabotierten Zustand (`sabotageRivalPrestigePenaltyPercent`).
  double sabotagedPrestige(int penaltyPercent) =>
      basePrestige * (100 - penaltyPercent) / 100;

  @override
  String toString() =>
      'RivalRestaurant(id=$id, name=$name, district=$district)';
}
