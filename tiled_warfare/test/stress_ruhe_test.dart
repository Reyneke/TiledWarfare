import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/game_clock_service.dart';
import 'package:tiled_warfare/services/stress_service.dart';

/// Deterministischer Zufall für Tests: gibt die geskripteten Werte der Reihe
/// nach zurück (modulo der angefragten Obergrenze) und zählt die Aufrufe.
class ScriptedRandom implements Random {
  final List<int> values;
  int calls = 0;

  ScriptedRandom(this.values);

  @override
  int nextInt(int max) {
    final v = values[calls % values.length];
    calls++;
    return v % max;
  }

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0.0;
}

/// Stress & Ruhe sowie der kumulative Erschöpfungs-Malus (V9 § 6, Phase 4).
void main() {
  final now = DateTime(2026, 6, 1, 12);

  test('Zielwert 0 ⇒ garantiert Stress (Erreichen von 0 = Kollaps)', () {
    final rng = ScriptedRandom([4, 0, 2, 39]);
    final override = StressService.probe(
      vitalityCurrent: 0,
      moraleCurrent: 50,
      currentProfileId: 5,
      random: rng,
    );
    expect(override, isNotNull);
    expect(override!.cause, 'stress');
    expect(override.profileId, 0);
    expect(override.duration, EconomyBalance.einzelTickUnit * 3);
  });

  test('kritische Unterschreitung ⇒ Ruhe', () {
    final rng = ScriptedRandom([54, 0, 0, 39]);
    final override = StressService.probe(
      vitalityCurrent: 80,
      moraleCurrent: 80,
      currentProfileId: 4,
      random: rng,
    );
    expect(override, isNotNull);
    expect(override!.cause, 'ruhe');
    expect(override.duration, EconomyBalance.stressWeekUnit);
  });

  test('normale Probe ⇒ kein Wechsel', () {
    final rng = ScriptedRandom([39, 39]);
    final override = StressService.probe(
      vitalityCurrent: 50,
      moraleCurrent: 50,
      currentProfileId: 1,
      random: rng,
    );
    expect(override, isNull);
  });

  test('Dauerstaffel: 1W6 Einzelticke bis 1W4 Monate', () {
    final zero = ScriptedRandom([0]);
    expect(
      StressService.durationForMargin(1, zero),
      EconomyBalance.einzelTickUnit,
    );
    expect(
      StressService.durationForMargin(5, zero),
      EconomyBalance.einzelTickUnit,
    );
    expect(StressService.durationForMargin(6, zero), EconomyBalance.stressDayUnit);
    expect(
      StressService.durationForMargin(15, zero),
      EconomyBalance.stressDayUnit,
    );
    expect(
      StressService.durationForMargin(16, zero),
      EconomyBalance.stressWeekUnit,
    );
    expect(
      StressService.durationForMargin(26, zero),
      EconomyBalance.stressMonthUnit,
    );
  });

  test('der Override-Profile-Wechsel weicht vom Grundprofil ab', () {
    expect(StressService.overrideProfileId(0, ScriptedRandom([0])), isNot(0));
    expect(StressService.overrideProfileId(3, ScriptedRandom([5])), 5);
  });

  test('Erschöpfungs-Malus: kumulativ, Doppel-Nullpunkt doppelt, kein Cap', () {
    expect(
      StressService.exhaustionMalusPercent(now: now),
      0,
    );
    expect(
      StressService.exhaustionMalusPercent(
        vitalityZeroSinceAt: now.subtract(const Duration(days: 3)),
        now: now,
      ),
      3 * EconomyBalance.resourceZeroMalusPerDay,
    );
    expect(
      StressService.exhaustionMalusPercent(
        vitalityZeroSinceAt: now.subtract(const Duration(days: 2)),
        moraleZeroSinceAt: now.subtract(const Duration(days: 2)),
        now: now,
      ),
      2 * EconomyBalance.resourceZeroMalusPerDayBoth,
    );
    expect(
      StressService.exhaustionMalusPercent(
        vitalityZeroSinceAt: now.subtract(const Duration(days: 5)),
        moraleZeroSinceAt: now.subtract(const Duration(days: 2)),
        now: now,
      ),
      2 * EconomyBalance.resourceZeroMalusPerDayBoth +
          3 * EconomyBalance.resourceZeroMalusPerDay,
    );
  });

  test('der Malus mindert den Proben-Zielwert', () {
    final without = StressService.probe(
      vitalityCurrent: 60,
      moraleCurrent: 60,
      currentProfileId: 1,
      random: ScriptedRandom([54, 49]),
    );
    final with_ = StressService.probe(
      vitalityCurrent: 60,
      moraleCurrent: 60,
      currentProfileId: 1,
      random: ScriptedRandom([54, 4, 0, 49]),
      malusPercent: 20,
    );
    expect(without, isNull);
    expect(with_, isNotNull);
    expect(with_!.cause, 'stress');
  });

  test('Catch-up: genau ein Proben-Paar je Staffel', () {
    final rng = ScriptedRandom([39]);
    final restaurant = RestaurantData(
      name: 'Testrestaurant',
      budget: 10000,
      district: 'Harlem',
      lastSeenAt: DateTime(2026, 6, 1),
      weekAnchorAt: DateTime(2026, 6, 1),
      staff: [
        StaffData(
          name: 'Koch',
          imagePath: 'x.png',
          type: 'apprentice',
          id: 7,
          personalityId: 2,
          vitalityCurrent: 50,
          moraleCurrent: 50,
        ),
      ],
    );

    GameClockService.catchUp(restaurant, DateTime(2026, 6, 3), random: rng);

    // Zwei Würfe (je Ressource einer) – kein weiterer Wurf trotz 2 Tagen.
    expect(rng.calls, 2);
  });

  test('Catch-up setzt einen Override und läuft danach ab', () {
    final restaurant = RestaurantData(
      name: 'Testrestaurant',
      budget: 10000,
      district: 'Harlem',
      lastSeenAt: DateTime(2026, 6, 1),
      weekAnchorAt: DateTime(2026, 6, 1),
      staff: [
        StaffData(
          name: 'Koch',
          imagePath: 'x.png',
          type: 'apprentice',
          id: 7,
          personalityId: 4,
          vitalityCurrent: 0,
          moraleCurrent: 50,
        ),
      ],
    );

    GameClockService.catchUp(
      restaurant,
      DateTime(2026, 6, 2),
      random: ScriptedRandom([9, 0, 0, 39]),
    );
    final staff = restaurant.staff.single;
    expect(staff.personalityOverrideId, greaterThanOrEqualTo(0));
    expect(staff.personalityOverrideCause, 'stress');
    expect(staff.personalityOverrideUntil, isNotNull);

    // Nach Ablauf entfernt der nächste Catch-up den Override wieder. Vorher
    // werden die Ressourcen erholt, da ein Nullpunkt erneut Stress auslöst.
    staff.vitalityCurrent = 90;
    staff.moraleCurrent = 90;
    GameClockService.catchUp(
      restaurant,
      staff.personalityOverrideUntil!.add(const Duration(days: 1)),
      random: ScriptedRandom([69]),
    );
    expect(staff.personalityOverrideId, -1);
    expect(staff.personalityOverrideUntil, isNull);
  });

  test('Wochen-Refill löscht die Null-Anker (Malus fällt auf 0)', () {
    final restaurant = RestaurantData(
      name: 'Testrestaurant',
      budget: 10000,
      district: 'Harlem',
      lastSeenAt: DateTime(2026, 6, 1),
      weekAnchorAt: DateTime(2026, 6, 1),
      staff: [
        StaffData(
          name: 'Koch',
          imagePath: 'x.png',
          type: 'apprentice',
          id: 7,
          personalityId: 2,
          vitalityCurrent: 3,
          moraleCurrent: 3,
        ),
      ],
    );

    GameClockService.catchUp(
      restaurant,
      DateTime(2026, 6, 8),
      random: ScriptedRandom([39]),
    );
    final staff = restaurant.staff.single;
    expect(staff.vitalityZeroSinceAt, isNull);
    expect(staff.moraleZeroSinceAt, isNull);
    expect(
      StressService.malusPercentForStaffData(staff, DateTime(2026, 6, 8)),
      0,
    );
  });

  test('StaffData roundtrippt die V9-Override-/Anker-Felder', () {
    final s = StaffData(
      name: 'Koch',
      imagePath: 'x.png',
      type: 'apprentice',
      id: 11,
      personalityId: 6,
      personalityOverrideId: 9,
      personalityOverrideUntil: DateTime(2026, 6, 5, 9),
      personalityOverrideCause: 'ruhe',
      vitalityZeroSinceAt: DateTime(2026, 6, 2, 3),
      moraleZeroSinceAt: DateTime(2026, 6, 3, 3),
    );

    final restored = StaffData.fromJson(s.toJson());
    expect(restored.personalityOverrideId, 9);
    expect(restored.personalityOverrideUntil, DateTime(2026, 6, 5, 9));
    expect(restored.personalityOverrideCause, 'ruhe');
    expect(restored.vitalityZeroSinceAt, DateTime(2026, 6, 2, 3));
    expect(restored.moraleZeroSinceAt, DateTime(2026, 6, 3, 3));

    final legacy = StaffData.fromJson({
      'name': 'Alt',
      'imagePath': 'x.png',
      'type': 'apprentice',
    });
    expect(legacy.personalityOverrideId, -1);
    expect(legacy.personalityOverrideUntil, isNull);
    expect(legacy.vitalityZeroSinceAt, isNull);
  });
}