import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/frt_service.dart';
import 'package:tiled_warfare/services/game_clock_service.dart';

/// Tests der FRT-/Korruptions-Simulation (Kapitel 14).
///
/// Die Formeln sind rein und deterministisch; der Zustand lebt allein in
/// `RestaurantData.corruptionPercent` und wird über den Wochen-Tick (V8)
/// monoton fortgeschrieben.
void main() {
  final base = DateTime(2026, 1, 1, 12);

  StaffData cook() =>
      StaffData(name: 'Testkoch', imagePath: 'x.png', type: 'apprentice');

  RestaurantData restaurant({
    double corruption = 0,
    int budget = 10000,
    List<StaffData>? staff,
    DateTime? lastSeenAt,
  }) => RestaurantData(
    name: 'Test',
    budget: budget,
    corruptionPercent: corruption,
    lastSeenAt: lastSeenAt ?? base,
    staff: staff ?? const [],
  );

  group('FrtService – Anstieg & Clamps', () {
    test('clampCorruption klemmt auf 0–100', () {
      expect(FrtService.clampCorruption(-5), 0);
      expect(FrtService.clampCorruption(42.5), 42.5);
      expect(FrtService.clampCorruption(120), 100);
    });

    test('afterBlock steigt je vollendetem Block um perWeek', () {
      expect(
        FrtService.afterBlock(0),
        EconomyBalance.frtCorruptionPerWeekPercent,
      );
      expect(FrtService.afterBlock(99), 100); // geklemmt
      expect(FrtService.afterBlock(100), 100);
    });

    test('Sabotage und Eliminierung treiben die Korruption', () {
      expect(
        FrtService.addSabotage(0),
        EconomyBalance.frtCorruptionPerSabotagePercent,
      );
      expect(
        FrtService.addElimination(0),
        EconomyBalance.frtCorruptionPerEliminationPercent,
      );
      expect(FrtService.addSabotage(100, 3), 100);
    });
  });

  group('FrtService – Senkung', () {
    test('reduce bucht Monsterkills und Siege', () {
      final after = FrtService.reduce(10, monstersKilled: 4, victory: true);
      final expected =
          10 -
          4 * EconomyBalance.frtCorruptionReducePerMonsterPercent -
          EconomyBalance.frtCorruptionReducePerVictoryPercent;
      expect(after, closeTo(expected, 1e-9));
    });

    test('reduce fällt nie unter den Floor (0)', () {
      expect(FrtService.reduce(1, monstersKilled: 100, victory: true), 0);
    });
  });

  group('FrtService – Verlustschwelle (Hysterese)', () {
    test('unterhalb der Schwelle nicht verloren, ab Schwelle verloren', () {
      expect(FrtService.isDistrictLost(99.9), isFalse);
      expect(FrtService.isDistrictLost(100), isTrue);
    });

    test('erholbar: unter die Schwelle gefallen ⇒ nicht mehr verloren', () {
      final lost = FrtService.isDistrictLost(100);
      final recovered =
          FrtService.isDistrictLost(FrtService.reduce(100, victory: true));
      expect(lost, isTrue);
      expect(recovered, isFalse);
    });
  });

  group('FrtService – Formeln', () {
    test('monsterStrengthFactor: 0 % ⇒ 1.0, 50 % ⇒ 1.5, 100 % ⇒ 2.0', () {
      expect(FrtService.monsterStrengthFactor(0), 1.0);
      expect(FrtService.monsterStrengthFactor(50), closeTo(1.5, 1e-9));
      expect(FrtService.monsterStrengthFactor(100), closeTo(2.0, 1e-9));
    });

    test('scaleStat rundet deterministisch', () {
      expect(FrtService.scaleStat(10, 1.5), 15);
      expect(FrtService.scaleStat(7, 1.5), 11); // 10.5 → 11
    });

    test('incomeMalusPercent: 0 ⇒ 0 %, 50 ⇒ 15 %, 100 ⇒ 30 %', () {
      expect(FrtService.incomeMalusPercent(0), 0);
      expect(FrtService.incomeMalusPercent(50), closeTo(15, 1e-9));
      expect(FrtService.incomeMalusPercent(100), closeTo(30, 1e-9));
    });

    test('applyIncomeMalus: 1000 € bei 50 % Korruption ⇒ 850 €', () {
      expect(FrtService.applyIncomeMalus(1000, 50), 850);
      expect(FrtService.applyIncomeMalus(1000, 0), 1000);
    });

    test('powerProjectionIncomeFactor: Basis 1.0 bei 50 % ⇒ 0.85', () {
      expect(
        FrtService.powerProjectionIncomeFactor(1.0, 50),
        closeTo(0.85, 1e-9),
      );
      expect(
        FrtService.powerProjectionIncomeFactor(0.1, 100),
        greaterThanOrEqualTo(0),
      );
    });
  });

  group('GameClockService.catchUp – Korruption im Wochen-Tick', () {
    test('je vollendetem Block steigt die Korruption um mindestens perWeek', () {
      final r = restaurant(staff: [cook()]);
      final result = GameClockService.catchUp(
        r,
        base.add(const Duration(days: 14)),
      );
      expect(result.weeks, 2);
      // Der Wochenanstieg ist garantiert; zusätzlich können unentdeckte
      // FRT-Sabotagen (Kapitel 14, Q6) die Korruption weiter treiben.
      expect(r.corruptionPercent, greaterThanOrEqualTo(2.0));
      expect(result.corruptionPercent, r.corruptionPercent.round());
      expect(result.districtLost, isFalse);
    });

    test('Resttage (< 1 Woche) treiben die Korruption nicht', () {
      final r = restaurant(staff: [cook()]);
      final result = GameClockService.catchUp(
        r,
        base.add(const Duration(days: 3)),
      );
      expect(result.weeks, 0);
      expect(r.corruptionPercent, 0);
    });

    test('100 %-Schwelle markiert den Stadtteil als verloren (Q4)', () {
      final r = restaurant(staff: [cook()], corruption: 99.5);
      final result = GameClockService.catchUp(
        r,
        base.add(const Duration(days: 7)),
      );
      expect(result.districtLost, isTrue);
      expect(r.districtLost, isTrue);
      expect(r.districtLostAt, isNotNull);
      expect(r.isDissolved, isTrue);
      expect(r.corruptionPercent, 100);
    });

    test('Korruption senkt das passive Einkommen', () {
      final clean = restaurant(staff: [cook()]);
      final corrupt = restaurant(staff: [cook()], corruption: 50);
      final cleanResult = GameClockService.catchUp(
        clean,
        base.add(const Duration(days: 7)),
      );
      final corruptResult = GameClockService.catchUp(
        corrupt,
        base.add(const Duration(days: 7)),
      );
      expect(cleanResult.passiveIncome, greaterThan(0));
      expect(corruptResult.passiveIncome, lessThan(cleanResult.passiveIncome));
    });

    test('Idempotenz: zweiter Aufruf mit gleichem now ändert nichts', () {
      final r = restaurant(staff: [cook()]);
      final now = base.add(const Duration(days: 7));
      final first = GameClockService.catchUp(r, now);
      final second = GameClockService.catchUp(r, now);
      expect(first.weeks, 1);
      expect(second.weeks, 0);
      expect(r.corruptionPercent, closeTo(1.0, 1e-9));
    });

    test('Zwei Teil-Catch-ups ergeben denselben Korruptions-Endstand', () {
      final oneShot = restaurant(staff: [cook()]);
      final split = restaurant(staff: [cook()]);
      GameClockService.catchUp(oneShot, base.add(const Duration(days: 14)));
      GameClockService.catchUp(split, base.add(const Duration(days: 7)));
      GameClockService.catchUp(split, base.add(const Duration(days: 14)));
      expect(split.corruptionPercent, closeTo(oneShot.corruptionPercent, 1e-9));
      expect(oneShot.corruptionPercent, greaterThanOrEqualTo(2.0));
    });
  });

  group('RestaurantData – tolerant Persistenz (Kapitel 14)', () {
    test('Roundtrip erhält Korruption und Verlust-Marker', () {
      final r = restaurant(corruption: 42.5);
      r.districtLost = true;
      r.districtLostAt = base;
      final restored = RestaurantData.fromJson(r.toJson());
      expect(restored.corruptionPercent, closeTo(42.5, 1e-9));
      expect(restored.districtLost, isTrue);
      expect(restored.districtLostAt, base);
    });

    test('fehlende Felder ⇒ Defaults (0 / false / null)', () {
      final restored = RestaurantData.fromJson({'name': 'Alt'});
      expect(restored.corruptionPercent, 0);
      expect(restored.districtLost, isFalse);
      expect(restored.districtLostAt, isNull);
    });

    test('Werte außerhalb 0–100 werden geklemmt', () {
      final high = RestaurantData.fromJson({
        'name': 'X',
        'corruptionPercent': 150.0,
      });
      expect(high.corruptionPercent, 100);
      final low = RestaurantData.fromJson({
        'name': 'X',
        'corruptionPercent': -10,
      });
      expect(low.corruptionPercent, 0);
    });

    test('Schema-Version ist 11 (FRT-Fehde, C2)', () {
      expect(kProfileSchemaVersion, 11);
    });
  });
}
