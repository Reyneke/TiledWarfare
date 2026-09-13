import 'dart:math' as math;

import 'package:tiled_warfare/models/medic_quality.dart';
import 'package:tiled_warfare/models/restaurant_upgrade.dart';
import 'package:tiled_warfare/services/economy_balance.dart';

/// Reine, zustandslose Wirtschaftsfunktionen (V2).
///
/// Alle Funktionen arbeiten auf einfachen Werten und sind ohne Widgets oder
/// das `ObjectProfile`-Singleton testbar.
class EconomyService {
  EconomyService._();

  /// Gefechtsbelohnung (§ 2.2).
  ///
  /// Die Beute (`enemyMoneyValues`, die `moneyValue`-Summe der besiegten
  /// Gegner) wird **immer** gutgeschrieben; dazu kommt die Basisprämie
  /// (Sieg höher als Niederlage).
  static int battleReward({
    required bool playerWon,
    required Iterable<int> enemyMoneyValues,
  }) {
    final loot = enemyMoneyValues.fold<int>(0, (sum, value) => sum + value);
    final base = playerWon
        ? EconomyBalance.battleRewardBaseWin
        : EconomyBalance.battleRewardBaseLoss;
    return base + loot;
  }

  /// Wendet Negativzinsen auf ein negatives Budget an (§ 2.2).
  ///
  /// Bei negativem Bestand: `budget − ceil(|budget| × negativeInterestRate)`,
  /// sonst unverändert.
  static int applyNegativeInterest(int budget) {
    if (budget >= 0) return budget;
    final interest =
        (budget.abs() * EconomyBalance.negativeInterestRate).ceil();
    return budget - interest;
  }

  /// Summe der Wochenkosten aller Ärzte × [weeks].
  static int billWeeklyMedicCosts(Iterable<int> medicCostsPerWeek, int weeks) {
    if (weeks <= 0) return 0;
    final perWeek =
        medicCostsPerWeek.fold<int>(0, (sum, value) => sum + value);
    return perWeek * weeks;
  }

  /// Wochenkosten eines Teamarztes aus [quality] und [teamSize] (§ 4.5).
  ///
  /// Ersetzt die frühere `_computeWeeklyCost`-Formel und macht Qualität **und**
  /// Teamgröße wirksam.
  static int weeklyMedicCost(MedicQuality quality, int teamSize) {
    final spec = EconomyBalance.medicQualitySpecs[quality]!;
    final heads = math.max(0, teamSize);
    final teamMultiplier = 1.0 + heads * EconomyBalance.medicTeamCostPerHead;
    return (EconomyBalance.medicBaseCostPerWeek *
            spec.costMultiplier *
            teamMultiplier)
        .round();
  }

  /// `true`, wenn [budget] die Negativgrenze unterschreitet.
  static bool isBankrupt(int budget) => budget < EconomyBalance.negativeLimit;

  // ── Budget-Wächter (V7/L4) ─────────────────────────────────────────────

  /// `true`, wenn [cost] vom [budget] abgebucht werden darf, ohne die
  /// Negativgrenze zu unterschreiten.
  ///
  /// Einzige Quelle für die Budgetregel – alle Ausgaben (Anheuern, Fortbildung,
  /// Wiederbelebung, Notfall-Spritze) laufen hierüber.
  static bool canAfford({required int budget, required int cost}) =>
      budget - cost >= EconomyBalance.negativeLimit;

  // ── W100 & Erfahrung (V7/L1, L3) ───────────────────────────────────────

  /// Ein W100-Wurf (Domäne [EconomyBalance.d100Min]–[EconomyBalance.d100Max]).
  static int rollD100(math.Random random) =>
      random.nextInt(EconomyBalance.d100Max) + EconomyBalance.d100Min;

  /// Begrenzt einen W100-Zielwert auf die gültige Domäne.
  static int clampTargetToD100(int target) =>
      target.clamp(EconomyBalance.d100Min, EconomyBalance.d100Max);

  /// XP-Belohnung eines Charakters nach einem Gefecht (§ 3.1).
  static int xpForBattle({required bool won, required int level}) => won
      ? EconomyBalance.xpBaseWin + level * EconomyBalance.xpPerLevelWin
      : EconomyBalance.xpBaseLoss;

  /// XP-Schwelle für den Aufstieg von [level] auf `level + 1` (§ 3.1).
  static int levelUpThreshold(int level) =>
      level * EconomyBalance.levelUpXpPerLevel;

  // ── Erweiterungen (§ 10) ──────────────────────────────────────────────

  /// Fasst die relativen Boni aller [levels] zu drei Summenboni zusammen.
  static ({double capacity, double attractiveness, double satisfaction})
      upgradeEffects(Map<UpgradeType, int> levels) {
    var capacity = 0.0;
    var attractiveness = 0.0;
    var satisfaction = 0.0;
    levels.forEach((type, level) {
      final spec = EconomyBalance.upgrades[type];
      if (spec == null || level <= 0) return;
      capacity += spec.capacityBonusPerLevel * level;
      attractiveness += spec.attractivenessBonusPerLevel * level;
      satisfaction += spec.satisfactionBonusPerLevel * level;
    });
    return (
      capacity: capacity,
      attractiveness: attractiveness,
      satisfaction: satisfaction,
    );
  }

  /// Kumulative Anschaffungskosten, um [type] auf [toLevel] zu bringen.
  ///
  /// `Σ Basis×k = Basis × N·(N+1)/2`.
  static int upgradeCost(UpgradeType type, int toLevel) {
    final spec = EconomyBalance.upgrades[type];
    if (spec == null || toLevel <= 0) return 0;
    final level = toLevel.clamp(0, spec.maxLevel);
    return spec.buyBaseCost * level * (level + 1) ~/ 2;
  }

  /// Wöchentlicher Unterhalt von [type] auf Stufe [level].
  static int upgradeUpkeepPerWeek(UpgradeType type, int level) {
    final spec = EconomyBalance.upgrades[type];
    if (spec == null || level <= 0) return 0;
    final clamped = level.clamp(0, spec.maxLevel);
    return spec.upkeepBaseCostPerWeek * clamped;
  }

  /// Summe des wöchentlichen Unterhalts aller [levels].
  static int totalUpgradeUpkeepPerWeek(Map<UpgradeType, int> levels) {
    var total = 0;
    levels.forEach((type, level) {
      total += upgradeUpkeepPerWeek(type, level);
    });
    return total;
  }

  /// Erstattung beim Verkauf von [type] auf Stufe [level].
  static int sellRefund(UpgradeType type, int level) {
    final invested = upgradeCost(type, level);
    return (invested * EconomyBalance.upgradeSellRefundRate).round();
  }
}
