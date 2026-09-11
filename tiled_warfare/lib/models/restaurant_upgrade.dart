/// Erweiterungstypen des Restaurants (§ 10).
///
/// Die konkreten Balance-Werte (Maximalstufe, Ankauf-/Erhalt-Basis, Boni)
/// liegen zentral in `EconomyBalance.upgrades` (V7).
enum UpgradeType {
  /// Mehr Tische – Kapazität & Kundenzufriedenheit.
  tables,

  /// Größere Küche – Kapazität.
  kitchen,

  /// Werbeplakate – Attraktivität.
  signage,

  /// Dekorationen – Attraktivität & Kundenzufriedenheit.
  decoration,

  /// Musikautomat – Attraktivität (Einzelstufe).
  jukebox,
}

/// Balance-Definition einer Restaurant-Erweiterung (§ 10).
///
/// Alle Kosten skalieren **linear mit der Stufe**: Der Ausbau **auf** Stufe `N`
/// kostet `buyBaseCost × N`; der wöchentliche Unterhalt **auf** Stufe `N`
/// beträgt `upkeepBaseCostPerWeek × N`. Kumulativ bis Stufe `N` sind
/// `buyBaseCost × N·(N+1)/2` investiert.
class UpgradeSpec {
  /// Maximale Ausbaustufe.
  final int maxLevel;

  /// Ankauf-Basis pro Stufe (Kosten zum Erreichen von Stufe `N` = Basis × N).
  final int buyBaseCost;

  /// Erhalt-Basis pro Woche und Stufe (Unterhalt auf Stufe `N` = Basis × N).
  final int upkeepBaseCostPerWeek;

  /// Kapazitäts-Bonus pro Stufe (relativ, z. B. 0.05 = +5 %).
  final double capacityBonusPerLevel;

  /// Attraktivitäts-Bonus pro Stufe (relativ).
  final double attractivenessBonusPerLevel;

  /// Kundenzufriedenheits-Bonus pro Stufe (relativ).
  final double satisfactionBonusPerLevel;

  const UpgradeSpec({
    required this.maxLevel,
    required this.buyBaseCost,
    required this.upkeepBaseCostPerWeek,
    this.capacityBonusPerLevel = 0.0,
    this.attractivenessBonusPerLevel = 0.0,
    this.satisfactionBonusPerLevel = 0.0,
  });
}
