import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/economy_service.dart';
import 'package:tiled_warfare/services/passive_income_service.dart';

void main() {
  test('Baseline (1/1/1) liefert mehr als 0 Kunden', () {
    final customers = PassiveIncomeService.customersPerWeek(
      attractiveness: 1,
      satisfaction: 1,
      capacity: 1,
    );
    expect(customers, greaterThan(0));
  });

  test('ohne Personal (Kapazität 0) entsteht kein Einkommen', () {
    expect(
      PassiveIncomeService.customersPerWeek(
        attractiveness: 4,
        satisfaction: 4,
        capacity: 0,
      ),
      0,
    );
    expect(
      PassiveIncomeService.passiveIncomePerWeek(
        attractiveness: 4,
        satisfaction: 4,
        capacity: 0,
      ),
      0,
    );
  });

  test('höhere Eingänge liefern mindestens so viele Kunden (Monotonie)', () {
    final base = PassiveIncomeService.customersPerWeek(
      attractiveness: 1,
      satisfaction: 1,
      capacity: 1,
    );
    final high = PassiveIncomeService.customersPerWeek(
      attractiveness: 4,
      satisfaction: 4,
      capacity: 4,
    );
    expect(high, greaterThanOrEqualTo(base));
  });

  test('Einkommen = Kunden × Satz', () {
    const att = 2.0;
    const sat = 2.0;
    const cap = 6.0;
    final customers = PassiveIncomeService.customersPerWeek(
      attractiveness: att,
      satisfaction: sat,
      capacity: cap,
    );
    expect(
      PassiveIncomeService.passiveIncomePerWeek(
        attractiveness: att,
        satisfaction: sat,
        capacity: cap,
      ),
      customers * EconomyBalance.passiveIncomePerCustomerPerWeek,
    );
  });

  test('Baseline-Passiveinkommen ist kleiner als die Basis-Gefechtsbelohnung', () {
    final passive = PassiveIncomeService.passiveIncomePerWeek(
      attractiveness: 1,
      satisfaction: 1,
      capacity: 1,
    );
    // Ein Gefecht zahlt mindestens die Basisprämie (ohne Beute).
    final minWinReward = EconomyService.battleReward(
      playerWon: true,
      enemyMoneyValues: const [],
    );
    expect(passive, greaterThan(0));
    expect(passive, lessThan(minWinReward));
  });

  test('Kunden/Woche ist auf 100 gedeckelt (Einkommen ≤ 100 × Satz)', () {
    final income = PassiveIncomeService.passiveIncomePerWeek(
      attractiveness: 4,
      satisfaction: 4,
      capacity: 20,
    );
    expect(
      income,
      lessThanOrEqualTo(100 * EconomyBalance.passiveIncomePerCustomerPerWeek),
    );
  });
}
