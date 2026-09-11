import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/services/game_clock_service.dart';

void main() {
  final base = DateTime(2026, 1, 1, 12);

  group('GameClockService Zeitrechnung', () {
    test('elapsed kappt negative Differenzen auf 0', () {
      expect(
        GameClockService.elapsed(base, base.subtract(const Duration(days: 1))),
        Duration.zero,
      );
      expect(
        GameClockService.elapsed(base, base.add(const Duration(days: 2))),
        const Duration(days: 2),
      );
    });

    test('weeksElapsed zählt volle Wochen', () {
      expect(GameClockService.weeksElapsed(base, base), 0);
      expect(
        GameClockService.weeksElapsed(base, base.add(const Duration(days: 6))),
        0,
      );
      expect(
        GameClockService.weeksElapsed(base, base.add(const Duration(days: 7))),
        1,
      );
      expect(
        GameClockService.weeksElapsed(base, base.add(const Duration(days: 30))),
        4,
      );
    });

    test('nextWeeklyTick liegt in der kommenden Woche', () {
      expect(
        GameClockService.nextWeeklyTick(base, base.add(const Duration(days: 3))),
        base.add(const Duration(days: 7)),
      );
      expect(
        GameClockService.nextWeeklyTick(base, base.add(const Duration(days: 8))),
        base.add(const Duration(days: 14)),
      );
    });
  });

  group('GameClockService.catchUp', () {
    RestaurantData restaurant({int budget = 10000, List<MedicData>? medics}) =>
        RestaurantData(
          name: 'Test',
          budget: budget,
          lastSeenAt: base,
          medics: medics ?? const [],
        );

    test('0 Wochen = No-op (nur Anker wird fortgeschrieben)', () {
      final r = restaurant();
      final result = GameClockService.catchUp(
        r,
        base.add(const Duration(days: 3)),
      );
      expect(result.weeks, 0);
      expect(r.budget, 10000);
      expect(r.lastSeenAt, base.add(const Duration(days: 3)));
    });

    test('bucht passives Einkommen, Arztkosten und Zinsen korrekt', () {
      final r = restaurant(
        budget: 10000,
        medics: [
          MedicData(
            id: 1,
            name: 'Dr. X',
            quality: 'niedrig',
            costPerWeek: 500,
            enneagramProfileName: 'Der Chaot',
          ),
        ],
      );
      final result = GameClockService.catchUp(
        r,
        base.add(const Duration(days: 14)),
      );
      expect(result.weeks, 2);
      expect(
        r.budget,
        10000 +
            result.passiveIncome -
            result.medicCosts -
            result.upgradeUpkeep -
            result.negativeInterest,
      );
      expect(r.lastSeenAt, base.add(const Duration(days: 14)));
    });

    test('ist idempotent (zweiter Aufruf bucht nicht doppelt)', () {
      final r = restaurant(
        budget: 10000,
        medics: [
          MedicData(
            id: 1,
            name: 'Dr. X',
            quality: 'hoch',
            costPerWeek: 1500,
            enneagramProfileName: 'Der Chaot',
          ),
        ],
      );
      final now = base.add(const Duration(days: 14));
      final first = GameClockService.catchUp(r, now);
      final budgetAfterFirst = r.budget;
      final second = GameClockService.catchUp(r, now);
      expect(second.weeks, 0);
      expect(r.budget, budgetAfterFirst);
      expect(second.budgetAfter, first.budgetAfter);
    });

    test('meldet Bankrott unterhalb der Negativgrenze', () {
      final r = restaurant(budget: -21000);
      final result = GameClockService.catchUp(
        r,
        base.add(const Duration(days: 7)),
      );
      expect(result.bankrupt, true);
    });

    test('wendet Negativzinsen pro Woche an (Verzinsung über Wochen)', () {
      final r = restaurant(budget: -1000);
      final result = GameClockService.catchUp(
        r,
        base.add(const Duration(days: 14)),
      );
      expect(result.weeks, 2);
      // Woche 1: 10 % auf -1000 = -100 → -1100
      // Woche 2: 10 % auf -1100 = -110 → -1210
      expect(result.negativeInterest, 210);
      expect(r.budget, -1210);
      expect(result.bankrupt, false);
    });

    test('greift auf Stadtteil/Prestige zu (Attraktivität)', () {
      final downtown = restaurant()..district = 'TriBeCa';
      final suburb = restaurant();
      expect(
        GameClockService.attractivenessOf(downtown),
        greaterThan(GameClockService.attractivenessOf(suburb)),
      );
    });
  });
}
