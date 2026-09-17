import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/services/game_clock_service.dart';
import 'package:tiled_warfare/services/passive_income_service.dart';

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

    test('daysElapsed zählt volle 24-h-Tage (floor)', () {
      expect(GameClockService.daysElapsed(base, base), 0);
      expect(
        GameClockService.daysElapsed(base, base.add(const Duration(hours: 23))),
        0,
      );
      expect(
        GameClockService.daysElapsed(base, base.add(const Duration(days: 3))),
        3,
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

    test('nextDailyTick liegt an der kommenden Tagesgrenze', () {
      expect(
        GameClockService.nextDailyTick(base, base.add(const Duration(hours: 5))),
        base.add(const Duration(days: 1)),
      );
      expect(
        GameClockService.nextDailyTick(base, base.add(const Duration(days: 2))),
        base.add(const Duration(days: 3)),
      );
    });

    test('hoursElapsed liefert die verstrichene Dauer (V3)', () {
      expect(GameClockService.hoursElapsed(base, base), Duration.zero);
      expect(
        GameClockService.hoursElapsed(base, base.add(const Duration(hours: 5))),
        const Duration(hours: 5),
      );
      expect(
        GameClockService.hoursElapsed(base, base.subtract(const Duration(hours: 1))),
        Duration.zero,
      );
    });
  });

  group('GameClockService.catchUp (Tagesschritt, § 6)', () {
    StaffData cook() =>
        StaffData(name: 'Testkoch', imagePath: 'x.png', type: 'apprentice');

    RestaurantData restaurant({
      int budget = 10000,
      List<MedicData>? medics,
      List<StaffData>? staff,
      DateTime? lastSeenAt,
      DateTime? weekAnchorAt,
    }) =>
        RestaurantData(
          name: 'Test',
          budget: budget,
          lastSeenAt: lastSeenAt ?? base,
          weekAnchorAt: weekAnchorAt,
          medics: medics ?? const [],
          staff: staff ?? const [],
        );

    /// Wochenertrag eines Restaurants (gleiche Eingangswerte wie im Catch-up).
    int weeklyIncome(RestaurantData r) =>
        PassiveIncomeService.passiveIncomePerWeek(
          attractiveness: GameClockService.attractivenessOf(r),
          satisfaction: GameClockService.satisfactionOf(r),
          capacity: GameClockService.capacityOf(r),
        );

    test('kein voller Tag = No-op (Anker unverändert, Rest bleibt)', () {
      final r = restaurant(staff: [cook()]);
      final result =
          GameClockService.catchUp(r, base.add(const Duration(hours: 23)));
      expect(result.weeks, 0);
      expect(result.passiveIncome, 0);
      expect(result.leftoverDays, 0);
      expect(r.budget, 10000);
      expect(r.lastSeenAt, base);
    });

    test('0 Wochen = No-op (Restaurant ohne Personal)', () {
      final r = restaurant();
      final result = GameClockService.catchUp(
        r,
        base.add(const Duration(days: 3)),
      );
      expect(result.weeks, 0);
      expect(result.passiveIncome, 0);
      expect(r.budget, 10000);
      expect(r.lastSeenAt, base.add(const Duration(days: 3)));
    });

    test('3 Tage buchen Resttage ohne Blockabschluss', () {
      final r = restaurant(staff: [cook()]);
      final perDay = weeklyIncome(r) ~/ 7;
      final result = GameClockService.catchUp(
        r,
        base.add(const Duration(days: 3)),
      );
      expect(result.weeks, 0);
      expect(result.settlements, isEmpty);
      expect(result.leftoverDays, 3);
      expect(result.leftoverIncome, perDay * 3);
      expect(result.passiveIncome, perDay * 3);
      expect(r.budget, 10000 + perDay * 3);
      expect(r.lastSeenAt, base.add(const Duration(days: 3)));
      expect(r.weekAnchorAt, base);
    });

    test('7 Tage = genau ein Block; Wochensumme exakt', () {
      final r = restaurant(
        staff: [cook()],
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
      final weekly = weeklyIncome(r);
      final result = GameClockService.catchUp(
        r,
        base.add(const Duration(days: 7)),
      );
      expect(result.weeks, 1);
      expect(result.settlements, hasLength(1));
      expect(result.settlements.single.income, weekly);
      expect(result.settlements.single.periodStart, base);
      expect(result.passiveIncome, weekly);
      expect(result.leftoverDays, 0);
      expect(result.leftoverIncome, 0);
      expect(r.budget, 10000 + weekly - 500 - result.staffCosts);
      expect(r.lastSeenAt, base.add(const Duration(days: 7)));
      expect(r.weekAnchorAt, base.add(const Duration(days: 7)));
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

    test('heilt auch bei 0 fälligen Wochen (V3)', () {
      final r = RestaurantData(
        name: 'Heilung',
        lastSeenAt: base,
        medics: [
          MedicData(
            id: 1,
            name: 'Dr. X',
            quality: 'hoch',
            costPerWeek: 500,
            enneagramProfileName: 'Der Chaot',
          ),
        ],
        staff: [
          StaffData(
            name: 'Testkoch',
            imagePath: 'x.png',
            type: 'apprentice',
            status: 'dying',
            injuryStartedAt: base,
          ),
        ],
      );
      final result = GameClockService.catchUp(
        r,
        base.add(const Duration(hours: 2)),
      );
      expect(result.weeks, 0);
      expect(r.staff.first.status, 'hurt');
    });

    test('8 Tage = ein Block + ein Resttag', () {
      final r = restaurant(staff: [cook()]);
      final weekly = weeklyIncome(r);
      final perDay = weekly ~/ 7;
      final result = GameClockService.catchUp(
        r,
        base.add(const Duration(days: 8)),
      );
      expect(result.weeks, 1);
      expect(result.leftoverDays, 1);
      expect(result.leftoverIncome, perDay);
      expect(result.passiveIncome, weekly + perDay);
      expect(r.weekAnchorAt, base.add(const Duration(days: 7)));
    });

    test('30 Tage = 4 Blöcke + 2 Resttage', () {
      final r = restaurant(staff: [cook()]);
      final weekly = weeklyIncome(r);
      final perDay = weekly ~/ 7;
      final result = GameClockService.catchUp(
        r,
        base.add(const Duration(days: 30)),
      );
      expect(result.weeks, 4);
      expect(result.settlements, hasLength(4));
      expect(result.leftoverDays, 2);
      expect(result.leftoverIncome, perDay * 2);
      expect(result.passiveIncome, weekly * 4 + perDay * 2);
    });

    test('Tagesbuchungen summieren sich exakt zur Woche (Rundung)', () {
      final r = restaurant(staff: [cook(), cook()]);
      final weekly = weeklyIncome(r);
      var total = 0;
      var settlements = 0;
      for (var d = 1; d <= 7; d++) {
        final res = GameClockService.catchUp(r, base.add(Duration(days: d)));
        total += res.passiveIncome;
        settlements += res.weeks;
      }
      expect(settlements, 1);
      expect(total, weekly);
      // Wochenraster bleibt trotz täglicher Catch-ups stabil (kein Drift).
      expect(r.weekAnchorAt, base.add(const Duration(days: 7)));
      expect(r.lastSeenAt, base.add(const Duration(days: 7)));
    });

    test('Wochenraster bleibt bei häufigen Catch-ups stabil', () {
      final r = restaurant(staff: [cook()]);
      final first =
          GameClockService.catchUp(r, base.add(const Duration(days: 6)));
      expect(first.weeks, 0);
      final second =
          GameClockService.catchUp(r, base.add(const Duration(days: 7)));
      expect(second.weeks, 1);
      expect(second.settlements.single.periodStart, base);
    });

    test('lastSeenAt == null setzt beide Anker ohne Buchung', () {
      final r = RestaurantData(name: 'Neu', staff: [cook()]);
      final result = GameClockService.catchUp(r, base);
      expect(result.weeks, 0);
      expect(result.passiveIncome, 0);
      expect(r.lastSeenAt, base);
      expect(r.weekAnchorAt, base);
    });

    test('Uhr zurückgedreht: keine Buchung, Anker bleibt', () {
      final r = restaurant(staff: [cook()]);
      final result =
          GameClockService.catchUp(r, base.subtract(const Duration(days: 5)));
      expect(result.weeks, 0);
      expect(result.passiveIncome, 0);
      expect(r.budget, 10000);
      expect(r.lastSeenAt, base);
    });

    test('Zeitrechnung nutzt exakte 24-h-Einheiten (UTC, DST-frei)', () {
      final start = DateTime.utc(2026, 3, 26, 12);
      final r = RestaurantData(
        name: 'DST',
        lastSeenAt: start,
        weekAnchorAt: start,
        staff: [cook()],
      );
      final result = GameClockService.catchUp(r, DateTime.utc(2026, 4, 9, 12));
      expect(result.weeks, 2);
      expect(r.weekAnchorAt, DateTime.utc(2026, 4, 9, 12));
    });
  });
}
