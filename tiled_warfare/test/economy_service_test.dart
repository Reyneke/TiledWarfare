import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/medic_quality.dart';
import 'package:tiled_warfare/models/restaurant_upgrade.dart';
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

    test('Kosten-Delta der nächsten Stufe (linear wachsend)', () {
      // tables: Basis 100 → nächste Stufe = 100 × (Stufe + 1)
      expect(EconomyService.upgradeCostDelta(UpgradeType.tables, 0), 100);
      expect(EconomyService.upgradeCostDelta(UpgradeType.tables, 1), 200);
      expect(EconomyService.upgradeCostDelta(UpgradeType.tables, 3), 400);
      // Delta = Differenz der kumulierten Kosten
      expect(
        EconomyService.upgradeCostDelta(UpgradeType.kitchen, 2),
        EconomyService.upgradeCost(UpgradeType.kitchen, 3) -
            EconomyService.upgradeCost(UpgradeType.kitchen, 2),
      );
    });

    test('Kosten-Delta ist 0 auf MaxLevel und bei negativer Stufe', () {
      // jukebox maxLevel 1 → kein weiterer Ausbau mehr möglich
      expect(EconomyService.upgradeCostDelta(UpgradeType.jukebox, 1), 0);
      expect(EconomyService.upgradeCostDelta(UpgradeType.tables, 5), 0);
      expect(EconomyService.upgradeCostDelta(UpgradeType.tables, -1), 0);
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

    test('Keller (V1-Paket) speist Zufriedenheit vor Attraktivität', () {
      // cellar: +2 % Zufriedenheit, +1 % Attraktivität je Stufe (Basis 180 €).
      final effects = EconomyService.upgradeEffects(
        const {UpgradeType.cellar: 3},
      );
      expect(effects.satisfaction, closeTo(0.06, 1e-9));
      expect(effects.attractiveness, closeTo(0.03, 1e-9));
      expect(effects.capacity, closeTo(0.0, 1e-9));

      expect(EconomyService.upgradeCost(UpgradeType.cellar, 5), 2700);
      expect(EconomyService.upgradeCostDelta(UpgradeType.cellar, 0), 180);
      expect(EconomyService.upgradeUpkeepPerWeek(UpgradeType.cellar, 5), 90);
      expect(EconomyService.sellRefund(UpgradeType.cellar, 5), 1350);
    });

    test('Kühlhaus (V1-Paket) speist ausschließlich Kapazität', () {
      // coldRoom: +3 % Kapazität je Stufe (Basis 160 €).
      final effects = EconomyService.upgradeEffects(
        const {UpgradeType.coldRoom: 4},
      );
      expect(effects.capacity, closeTo(0.12, 1e-9));
      expect(effects.attractiveness, closeTo(0.0, 1e-9));
      expect(effects.satisfaction, closeTo(0.0, 1e-9));

      expect(EconomyService.upgradeCost(UpgradeType.coldRoom, 5), 2400);
      expect(EconomyService.upgradeCostDelta(UpgradeType.coldRoom, 0), 160);
      expect(EconomyService.upgradeUpkeepPerWeek(UpgradeType.coldRoom, 5), 80);
      expect(EconomyService.sellRefund(UpgradeType.coldRoom, 5), 1200);
    });

    test('Erste-Hilfe-Station (V1-Paket) verkürzt ausschließlich die Heilzeit',
        () {
      // firstAid: −5 % Heilzeit je Stufe (Basis 250 €, max. 3 Stufen).
      final effects = EconomyService.upgradeEffects(
        const {UpgradeType.firstAid: 3},
      );
      expect(effects.healTime, closeTo(0.15, 1e-9));
      // Bewusst kein Zuwachs auf einen der drei Eingangswerte (§ 8).
      expect(effects.capacity, closeTo(0.0, 1e-9));
      expect(effects.attractiveness, closeTo(0.0, 1e-9));
      expect(effects.satisfaction, closeTo(0.0, 1e-9));

      expect(EconomyService.upgradeCost(UpgradeType.firstAid, 3), 1500);
      expect(EconomyService.upgradeCost(UpgradeType.firstAid, 5), 1500);
      expect(EconomyService.upgradeCostDelta(UpgradeType.firstAid, 0), 250);
      expect(EconomyService.upgradeCostDelta(UpgradeType.firstAid, 3), 0);
      expect(EconomyService.upgradeUpkeepPerWeek(UpgradeType.firstAid, 3), 75);
      expect(EconomyService.sellRefund(UpgradeType.firstAid, 3), 750);
    });

    test('Ruheraum (V1-Paket) speist Refill und Sink-Erleichterung', () {
      // lounge: +3 % Wochen-Refill und −3 % Tages-Sink je Stufe
      // (Basis 180 €, max. 3 Stufen) – entschiedene Wirkungs-Option „und“.
      final effects = EconomyService.upgradeEffects(
        const {UpgradeType.lounge: 3},
      );
      expect(effects.refill, closeTo(0.09, 1e-9));
      expect(effects.dailySinkRelief, closeTo(0.09, 1e-9));
      // Bewusst kein Zuwachs auf einen der drei Eingangswerte oder die Heilzeit.
      expect(effects.capacity, closeTo(0.0, 1e-9));
      expect(effects.attractiveness, closeTo(0.0, 1e-9));
      expect(effects.satisfaction, closeTo(0.0, 1e-9));
      expect(effects.healTime, closeTo(0.0, 1e-9));

      expect(EconomyService.upgradeCost(UpgradeType.lounge, 3), 1080);
      expect(EconomyService.upgradeCost(UpgradeType.lounge, 5), 1080);
      expect(EconomyService.upgradeCostDelta(UpgradeType.lounge, 0), 180);
      expect(EconomyService.upgradeCostDelta(UpgradeType.lounge, 3), 0);
      expect(EconomyService.upgradeUpkeepPerWeek(UpgradeType.lounge, 3), 54);
      expect(EconomyService.sellRefund(UpgradeType.lounge, 3), 540);
    });

    test('nur der Ruheraum speist die Personal-Ressourcen-Summen (§ 10)', () {
      final effects = EconomyService.upgradeEffects(
        const {
          UpgradeType.tables: 3,
          UpgradeType.cellar: 3,
          UpgradeType.coldRoom: 3,
          UpgradeType.firstAid: 3,
          UpgradeType.lounge: 3,
        },
      );
      expect(effects.refill, closeTo(0.09, 1e-9));
      expect(effects.dailySinkRelief, closeTo(0.09, 1e-9));
    });
  });

  group('EconomyService V7-Helfer', () {
    test('xpForBattle: Sieg nutzt Basis + Level, Niederlage die Basisstrafe', () {
      expect(
        EconomyService.xpForBattle(won: true, level: 1),
        EconomyBalance.xpBaseWin + EconomyBalance.xpPerLevelWin,
      );
      expect(
        EconomyService.xpForBattle(won: true, level: 5),
        EconomyBalance.xpBaseWin + 5 * EconomyBalance.xpPerLevelWin,
      );
      expect(
        EconomyService.xpForBattle(won: false, level: 9),
        EconomyBalance.xpBaseLoss,
      );
    });

    test('levelUpThreshold skaliert linear mit dem Level', () {
      expect(
        EconomyService.levelUpThreshold(1),
        EconomyBalance.levelUpXpPerLevel,
      );
      expect(
        EconomyService.levelUpThreshold(3),
        3 * EconomyBalance.levelUpXpPerLevel,
      );
    });

    test('canAfford erlaubt Schulden bis zur Negativgrenze', () {
      expect(EconomyService.canAfford(budget: 100, cost: 100), true);
      expect(
        EconomyService.canAfford(budget: 0, cost: EconomyBalance.revivalCost),
        true, // 0 − 200 = −200 ≥ −20.000
      );
      expect(
        EconomyService.canAfford(
          budget: EconomyBalance.negativeLimit + 1,
          cost: 1,
        ),
        true, // exakt −20.000
      );
      expect(
        EconomyService.canAfford(
          budget: EconomyBalance.negativeLimit,
          cost: 1,
        ),
        false, // würde −20.001 ergeben
      );
    });

    test('rollD100 liefert Werte in 1–100', () {
      final random = Random(42);
      for (var i = 0; i < 500; i++) {
        final roll = EconomyService.rollD100(random);
        expect(
          roll,
          inInclusiveRange(EconomyBalance.d100Min, EconomyBalance.d100Max),
        );
      }
    });

    test('clampTargetToD100 begrenzt auf die Domäne', () {
      expect(EconomyService.clampTargetToD100(-5), EconomyBalance.d100Min);
      expect(EconomyService.clampTargetToD100(150), EconomyBalance.d100Max);
      expect(EconomyService.clampTargetToD100(50), 50);
    });
  });
}
