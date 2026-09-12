import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/match_record.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/models/restaurant_upgrade.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/economy_service.dart';
import 'package:tiled_warfare/services/game_clock_service.dart';
import 'package:tiled_warfare/services/passive_income_service.dart';

/// Balance-Sanity-Tests (V7): schreiben die gewünschten Eigenschaften der
/// Wirtschaftsschleife fest, damit Tuning-Änderungen sie nicht unbemerkt
/// brechen.
void main() {
  group('Balance-Tuning: Konfiguration ist konsistent', () {
    test('Fuzzy-Peaks sind geordnet und innerhalb der Domänen', () {
      expect(
        EconomyBalance.fuzzyInputLowPeak,
        lessThan(EconomyBalance.fuzzyInputMidPeak),
      );
      expect(
        EconomyBalance.fuzzyInputMidPeak,
        lessThan(EconomyBalance.fuzzyInputHighPeak),
      );
      expect(
        EconomyBalance.fuzzyInputHighPeak,
        lessThanOrEqualTo(EconomyBalance.inputDomainMax),
      );

      expect(
        EconomyBalance.fuzzyCapacityLowPeak,
        lessThan(EconomyBalance.fuzzyCapacityMidPeak),
      );
      expect(
        EconomyBalance.fuzzyCapacityMidPeak,
        lessThan(EconomyBalance.fuzzyCapacityHighPeak),
      );
      expect(
        EconomyBalance.fuzzyCapacityHighPeak,
        lessThanOrEqualTo(EconomyBalance.capacityMax),
      );

      expect(EconomyBalance.fuzzyFewRepresentative, greaterThan(0));
      expect(
        EconomyBalance.fuzzyFewRepresentative,
        lessThan(EconomyBalance.fuzzyCustomersMidPeak),
      );
      expect(
        EconomyBalance.fuzzyCustomersMidPeak,
        lessThan(EconomyBalance.customersDomainMax),
      );
    });

    test('Budget-/Zins-Invarianten', () {
      expect(EconomyBalance.startBudget, greaterThan(0));
      expect(EconomyBalance.negativeLimit, lessThan(0));
      expect(EconomyBalance.negativeInterestRate, greaterThan(0));
      expect(EconomyBalance.medicBaseCostPerWeek, greaterThan(0));
    });

    test('jede Erweiterung hat eine positive Spec mit mindestens einer Stufe',
        () {
      for (final type in UpgradeType.values) {
        final spec = EconomyBalance.upgrades[type];
        expect(spec, isNotNull, reason: 'Fehlende Spec für $type');
        expect(spec!.maxLevel, greaterThanOrEqualTo(1));
        expect(spec.buyBaseCost, greaterThan(0));
        expect(spec.upkeepBaseCostPerWeek, greaterThan(0));
      }
    });
  });

  group('Balance-Tuning: Einkommen & Zufriedenheit', () {
    RestaurantData restaurant({
      List<StaffData>? staff,
      MatchResult? result,
    }) =>
        RestaurantData(
          name: 'Balance',
          district: 'Harlem',
          staff: staff ?? [],
          lastMatchResult: result,
        );

    StaffData staff({
      String status = 'ready',
      int moneyValue = 100,
    }) =>
        StaffData(
          name: 'Testkoch',
          imagePath: 'assets/images/token/token_cook_basic.png',
          type: 'apprentice',
          status: status,
          moneyValue: moneyValue,
        );

    int passiveIncome(RestaurantData r) => PassiveIncomeService.passiveIncomePerWeek(
          attractiveness: GameClockService.attractivenessOf(r),
          satisfaction: GameClockService.satisfactionOf(r),
          capacity: GameClockService.capacityOf(r),
        );

    test('frisches Restaurant erwirtschaftet passiv Geld, aber weniger als ein Sieg',
        () {
      final fresh = restaurant(staff: [staff()]);
      final income = passiveIncome(fresh);

      expect(income, greaterThan(0));
      expect(income, lessThan(EconomyBalance.battleRewardBaseWin));
    });

    test('gesundes Team sättigt die Zufriedenheit nicht (Ergebnis wirkt)', () {
      final healthy = restaurant(staff: [staff()]);
      final sat = GameClockService.satisfactionOf(healthy);

      expect(sat, greaterThan(EconomyBalance.satisfactionBase));
      expect(sat, lessThan(EconomyBalance.inputDomainMax));

      final won = restaurant(staff: [staff()], result: MatchResult.win);
      final lost = restaurant(staff: [staff()], result: MatchResult.loss);
      expect(
        GameClockService.satisfactionOf(won),
        greaterThan(GameClockService.satisfactionOf(lost)),
      );
    });

    test('gesundes Team ist besser als todkrankes (Teamgesundheit wirkt)', () {
      final healthy = restaurant(staff: [staff()]);
      final sick = restaurant(staff: [staff(status: 'dying')]);

      expect(
        GameClockService.teamHealthOf(healthy),
        greaterThan(GameClockService.teamHealthOf(sick)),
      );
      expect(
        GameClockService.satisfactionOf(healthy),
        greaterThan(GameClockService.satisfactionOf(sick)),
      );
    });

    test('Maximal-Einkommen ist gedeckelt und unter üppigen Gefechtserlösen', () {
      final maxIncome = PassiveIncomeService.passiveIncomePerWeek(
        attractiveness: EconomyBalance.inputDomainMax,
        satisfaction: EconomyBalance.inputDomainMax,
        capacity: EconomyBalance.capacityMax,
      );

      expect(
        maxIncome,
        lessThanOrEqualTo(EconomyBalance.customersDomainMax *
            EconomyBalance.passiveIncomePerCustomerPerWeek),
      );

      final richBattle = EconomyService.battleReward(
        playerWon: true,
        enemyMoneyValues: const [1000, 1000, 1000],
      );
      expect(maxIncome, lessThan(richBattle));
    });
  });
}
