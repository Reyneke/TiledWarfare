import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/restaurant_upgrade.dart';
import 'package:tiled_warfare/objects/object_team_medic.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/economy_service.dart';

void main() {
  group('EconomyService.applyNegativeInterest', () {
    test('lässt positives/Null-Budget unverändert', () {
      expect(EconomyService.applyNegativeInterest(1000), 1000);
      expect(EconomyService.applyNegativeInterest(0), 0);
    });

    test('wendet 10 % (ceil) auf negatives Budget an', () {
      expect(EconomyService.applyNegativeInterest(-100), -110);
      expect(EconomyService.applyNegativeInterest(-1000), -1100);
    });
  });

  group('EconomyService.battleReward', () {
    test('Sieg = Basisprämie + Beute', () {
      expect(
        EconomyService.battleReward(
          playerWon: true,
          enemyMoneyValues: const [100, 100],
        ),
        EconomyBalance.battleRewardBaseWin + 200,
      );
    });

    test('Niederlage = reduzierte Prämie + Beute', () {
      expect(
        EconomyService.battleReward(
          playerWon: false,
          enemyMoneyValues: const [100],
        ),
        EconomyBalance.battleRewardBaseLoss + 100,
      );
    });

    test('leere Beute = nur Basisprämie', () {
      expect(
        EconomyService.battleReward(playerWon: true, enemyMoneyValues: const []),
        EconomyBalance.battleRewardBaseWin,
      );
    });
  });

  group('EconomyService.billWeeklyMedicCosts', () {
    test('0 Wochen = 0', () {
      expect(EconomyService.billWeeklyMedicCosts(const [500, 300], 0), 0);
    });

    test('n Wochen multiplizieren die Wochensumme', () {
      expect(EconomyService.billWeeklyMedicCosts(const [500], 3), 1500);
      expect(EconomyService.billWeeklyMedicCosts(const [500, 300], 2), 1600);
    });
  });

  group('EconomyService.weeklyMedicCost', () {
    test('Basis: niedrige Qualität, kein Team = Basiskosten', () {
      expect(
        EconomyService.weeklyMedicCost(MedicQuality.niedrig, 0),
        EconomyBalance.medicBaseCostPerWeek,
      );
    });

    test('größeres Team kostet mehr', () {
      final none = EconomyService.weeklyMedicCost(MedicQuality.niedrig, 0);
      final four = EconomyService.weeklyMedicCost(MedicQuality.niedrig, 4);
      expect(four, greaterThan(none));
    });

    test('höhere Qualität kostet mehr', () {
      final low = EconomyService.weeklyMedicCost(MedicQuality.niedrig, 2);
      final high = EconomyService.weeklyMedicCost(MedicQuality.hoch, 2);
      expect(high, greaterThan(low));
    });
  });

  group('EconomyService.isBankrupt', () {
    test('Grenze: exakt −20.000 ist nicht bankrott, darunter schon', () {
      expect(EconomyService.isBankrupt(EconomyBalance.negativeLimit), false);
      expect(EconomyService.isBankrupt(EconomyBalance.negativeLimit - 1), true);
      expect(EconomyService.isBankrupt(0), false);
    });
  });

  group('EconomyService Erweiterungen (§ 10)', () {
    test('kumulative Anschaffungskosten (lineares Modell)', () {
      // tables: Basis 100 → L1 = 100, L2 = 300, L3 = 600
      expect(EconomyService.upgradeCost(UpgradeType.tables, 1), 100);
      expect(EconomyService.upgradeCost(UpgradeType.tables, 2), 300);
      expect(EconomyService.upgradeCost(UpgradeType.tables, 3), 600);
    });

    test('Anschaffungskosten clampen auf MaxLevel', () {
      // jukebox maxLevel 1
      expect(EconomyService.upgradeCost(UpgradeType.jukebox, 5), 500);
    });

    test('Unterhalt skaliert linear mit der Stufe', () {
      expect(EconomyService.upgradeUpkeepPerWeek(UpgradeType.tables, 2), 20);
      expect(EconomyService.totalUpgradeUpkeepPerWeek(
        const {UpgradeType.tables: 2, UpgradeType.kitchen: 1},
      ), 40);
    });

    test('Verkaufserlös = 50 % der investierten Summe', () {
      expect(EconomyService.sellRefund(UpgradeType.tables, 2), 150);
    });

    test('Effekte aggregieren relativ', () {
      final effects = EconomyService.upgradeEffects(
        const {UpgradeType.signage: 2, UpgradeType.kitchen: 1},
      );
      expect(effects.attractiveness, closeTo(0.10, 1e-9));
      expect(effects.capacity, closeTo(0.05, 1e-9));
      expect(effects.satisfaction, closeTo(0.0, 1e-9));
    });
  });
}
