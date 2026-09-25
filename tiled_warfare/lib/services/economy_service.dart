import 'dart:math' as math;

import 'package:tiled_warfare/models/medic_quality.dart';
import 'package:tiled_warfare/models/restaurant_upgrade.dart';
import 'package:tiled_warfare/models/stations.dart';
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
  static int weeklyMedicCost(MedicQuality quality, int teamSize,
      [int thriftiness = 50]) {
    final spec = EconomyBalance.medicQualitySpecs[quality]!;
    final heads = math.max(0, teamSize);
    final teamMultiplier = 1.0 + heads * EconomyBalance.medicTeamCostPerHead;
    // V9 (Phase 3): Die Thriftiness des Arztes verschiebt die Lohnforderung
    // (50 = neutral, ± thriftinessWageSpread).
    final wageFactor =
        1.0 + (50 - thriftiness) / 50.0 * EconomyBalance.thriftinessWageSpread;
    return (EconomyBalance.medicBaseCostPerWeek *
            spec.costMultiplier *
            teamMultiplier *
            wageFactor)
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

  /// Wendet [xp] auf Level/XP an und führt Levelaufstiege nach (§ 3.1).
  ///
  /// Einzige Quelle der Aufstiegslogik (V7/„eine Quelle der Wahrheit“): sowohl
  /// `ObjectApprentice.earnXP` als auch die XP-Gutschriften des Catch-ups
  /// (Features, `11a`) laufen hierüber.
  static XpGrant grantXp({
    required int level,
    required int currentXp,
    required int xp,
  }) {
    var newLevel = level;
    var remaining = currentXp + xp;
    var gained = 0;
    while (remaining >= levelUpThreshold(newLevel)) {
      remaining -= levelUpThreshold(newLevel);
      newLevel++;
      gained++;
    }
    return XpGrant(level: newLevel, currentXp: remaining, levelsGained: gained);
  }

  /// Prozentualer XP-Zuschlag: `xp × (100 + percent) / 100`, kaufmännisch
  /// gerundet (Feature-Boost, `11a`).
  static int boostedXp(int xp, int percent) =>
      percent == 0 ? xp : (xp * (100 + percent) / 100).round();

  // ── Karrierepfade (V10) ───────────────────────────────────────────────

  /// Aufstiegs-Level für den Ziel-Rang [rank] (Karrierepfade, V10).
  static int promotionLevel(String rank) => switch (rank) {
        'line_cook' => EconomyBalance.lineCookPromotionLevel,
        'chef_de_partie' => EconomyBalance.chefDePartiePromotionLevel,
        'sous_chef' => EconomyBalance.sousChefPromotionLevel,
        'head_chef' => EconomyBalance.headChefPromotionLevel,
        _ => 1,
      };

  /// Einmalkosten des Aufstiegs in den Ziel-Rang [rank] (Karrierepfade, V10).
  static int promotionCost(String rank) => switch (rank) {
        'line_cook' => EconomyBalance.upgradeToLineCookCost,
        'chef_de_partie' => EconomyBalance.upgradeToChefDePartieCost,
        'sous_chef' => EconomyBalance.upgradeToSousChefCost,
        'head_chef' => EconomyBalance.upgradeToHeadChefCost,
        _ => 0,
      };

  /// `true`, wenn [level] den Aufstieg in den Ziel-Rang [rank] erlaubt.
  static bool canPromote({required String rank, required int level}) =>
      level >= promotionLevel(rank);

  /// Transferkosten einer Person mit [level] (Karrierepfade, V10).
  static int transferCost({required int level}) =>
      EconomyBalance.transferCostBase +
      EconomyBalance.transferCostPerLevel * math.max(0, level);

  /// Aura-Radius eines Kampfrangs [rank] in Hexfeldern (Karrierepfade, V10).
  static int stationAuraRadius(String rank) =>
      EconomyBalance.stationAuraRadiusByRank[rank] ?? 0;

  /// Nächster Rang in der Aufstiegsleiter (Karrierepfade, V10).
  ///
  /// `apprentice → line_cook → chef_de_partie → sous_chef → head_chef`;
  /// `null` = Ende der Kette (derzeit der Chef de cuisine).
  static String? nextRank(String rank) => switch (rank) {
        'apprentice' => 'line_cook',
        'line_cook' => 'chef_de_partie',
        'chef_de_partie' => 'sous_chef',
        'sous_chef' => 'head_chef',
        _ => null,
      };

  /// Vorheriger Rang in der Aufstiegsleiter – die Bedingung für einen Aufstieg
  /// in den Zielrang [rank]; `null` = unbekanntes Ziel.
  static String? previousRankOf(String rank) => switch (rank) {
        'line_cook' => 'apprentice',
        'chef_de_partie' => 'line_cook',
        'sous_chef' => 'chef_de_partie',
        'head_chef' => 'sous_chef',
        _ => null,
      };

  /// `true`, wenn [rank] eine Station wählen darf (Chef de partie und höher).
  static bool isStationRank(String rank) =>
      EconomyBalance.stationAuraRadiusByRank.containsKey(rank);

  /// `true`, wenn [station] eine bekannte Station ist.
  static bool isValidStation(String? station) =>
      station != null && EconomyBalance.stationSpecs.containsKey(station);

  /// Basis-Station einer Variante (`null` für Basis-Stationen/Unbekanntes).
  static String? baseStationOf(String? station) =>
      isValidStation(station)
          ? EconomyBalance.stationSpecs[station]!.baseStation
          : null;

  /// `true`, wenn [station] eine Support-Station ohne Kampf-Aura ist.
  static bool isSupportStation(String? station) =>
      isValidStation(station) &&
      EconomyBalance.stationSpecs[station]!.isSupport;

  /// Prozent-Bonus (Selbstwirkung) der [station] auf [stat], gedeckelt über
  /// [EconomyBalance.stationBonusMaxPercent]. `0` für unbekannte/keine Station.
  static int stationBonusPercent(String? station, StationStat stat) =>
      _capStationPercent(
          isValidStation(station)
              ? EconomyBalance.stationSpecs[station]!.selfBonusPercent(stat)
              : 0);

  /// Prozent-Bonus (Aura) der [station] auf [stat], gedeckelt und `0` für
  /// unbekannte/keine Station sowie für Support-Stationen.
  static int stationAuraPercent(String? station, StationStat stat) =>
      isValidStation(station) && !isSupportStation(station)
          ? _capStationPercent(
              EconomyBalance.stationSpecs[station]!.auraBonusPercent(stat))
          : 0;

  /// Begrenzt einen Stations-Prozentsatz auf
  /// `[-stationBonusMaxPercent, +stationBonusMaxPercent]` (V10 § 6).
  static int _capStationPercent(int percent) => percent.clamp(
        -EconomyBalance.stationBonusMaxPercent,
        EconomyBalance.stationBonusMaxPercent,
      );

  // ── Wöchentliche Löhne (V10, Phase 7) ──────────────────────────────────

  /// Wochenlohn eines Brigade-Rangs [rank] (Karrierepfade, V10).
  ///
  /// `Basislohn des Rangs × Thriftiness-Faktor` – derselbe Faktor wie beim
  /// Teamarzt (`weeklyMedicCost`): `50` = neutral, Sparsamkeit senkt den Lohn,
  /// Verschwendung hebt ihn (`EconomyBalance.thriftinessWageSpread`).
  static int staffWagePerWeek(String rank, [int thriftiness = 50]) {
    final base = EconomyBalance.staffWagePerWeekByRank[rank] ??
        EconomyBalance.staffWageFallbackPerWeek;
    final wageFactor = 1.0 +
        (50 - thriftiness) / 50.0 * EconomyBalance.thriftinessWageSpread;
    return (base * wageFactor).round();
  }

  /// Summe der Wochenlöhne mehrerer Personen × [weeks].
  static int billWeeklyStaffWages(Iterable<int> wagesPerWeek, int weeks) {
    if (weeks <= 0) return 0;
    final perWeek = wagesPerWeek.fold<int>(0, (sum, value) => sum + value);
    return perWeek * weeks;
  }

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

/// Ergebnis einer XP-Gutschrift (V7/L1; Levelaufstiege werden mitgeführt).
class XpGrant {
  /// Neues Level nach der Gutschrift.
  final int level;

  /// Verbleibende XP oberhalb der letzten Schwelle.
  final int currentXp;

  /// Anzahl der Levelaufstiege durch diese Gutschrift.
  final int levelsGained;

  const XpGrant({
    required this.level,
    required this.currentXp,
    required this.levelsGained,
  });
}
