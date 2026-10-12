import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/game_clock_service.dart';

/// Tests des Wochen-Caps `EconomyBalance.maxCatchUpWeeks` (L6): Eine zu lange
/// Abwesenheit wird nicht unbegrenzt nachgerechnet; der überstehende Zeitraum
/// wird ohne Buchung übersprungen, das Wochenraster bleibt erhalten.
void main() {
  final base = DateTime(2026, 1, 1);

  RestaurantData restaurant() => RestaurantData(
        id: 1,
        name: 'Test',
        district: 'Midtown',
        budget: 10000,
        lastSeenAt: base,
        weekAnchorAt: base,
        staff: [StaffData(name: 'Koch', imagePath: 'x.png', type: 'apprentice')],
      );

  group('GameClockService.catchUp: maxCatchUpWeeks-Cap (L6)', () {
    test('unterhalb des Caps werden alle Wochen abgerechnet', () {
      final weeks = EconomyBalance.maxCatchUpWeeks;
      final r = restaurant();
      final result =
          GameClockService.catchUp(r, base.add(Duration(days: weeks * 7)));
      expect(result.weeks, weeks);
      expect(result.settlements.length, weeks);
    });

    test('oberhalb des Caps wird auf den Cap gedeckelt', () {
      final cap = EconomyBalance.maxCatchUpWeeks;
      const extraWeeks = 10;
      final elapsedDays = (cap + extraWeeks) * 7;
      final r = restaurant();
      final result =
          GameClockService.catchUp(r, base.add(Duration(days: elapsedDays)));

      // Nur der Cap an Blöcken wird gebucht …
      expect(result.weeks, cap);
      expect(result.settlements.length, cap);
      // … die übersprungene Zeit wird aber vollständig nachgeholt.
      expect(r.lastSeenAt, base.add(Duration(days: elapsedDays)));
      expect(
        r.weekAnchorAt,
        base.add(Duration(days: elapsedDays)),
        reason: 'Wochenanker bleibt auf dem 7-Tage-Raster',
      );
    });

    test('Cap + Resttage: Resttage werden weiterhin abgerechnet', () {
      final cap = EconomyBalance.maxCatchUpWeeks;
      const extraDays = 3;
      final elapsedDays = cap * 7 + extraDays;
      final r = restaurant();
      final result =
          GameClockService.catchUp(r, base.add(Duration(days: elapsedDays)));
      expect(result.weeks, cap);
      expect(result.leftoverDays, extraDays);
      expect(r.lastSeenAt, base.add(Duration(days: elapsedDays)));
    });

    test('nach dem Cap ist ein zweiter Aufruf idempotent', () {
      final cap = EconomyBalance.maxCatchUpWeeks;
      final elapsedDays = (cap + 5) * 7;
      final now = base.add(Duration(days: elapsedDays));
      final r = restaurant();
      final first = GameClockService.catchUp(r, now);
      final budgetAfterFirst = r.budget;

      final second = GameClockService.catchUp(r, now);
      expect(second.weeks, 0);
      expect(second.passiveIncome, 0);
      expect(r.budget, budgetAfterFirst);
      expect(r.lastSeenAt, now);
      expect(first.weeks, cap);
    });
  });
}
