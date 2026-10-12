import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/frt_service.dart';
import 'package:tiled_warfare/services/game_clock_service.dart';
import 'package:tiled_warfare/services/rival_service.dart';

/// Laufzeit-Verdrahtung der FRT (Kapitel 14, Paket C).
///
/// Deckt die drei früheren Lücken ab:
/// - **A0:** Der reale Persistenzpfad (`ObjectProfile` → `RestaurantData`)
///   kennt die Korruptionsfelder und schreibt den Catch-up-Wert zurück.
/// - **Q8:** Die Korruption mindert zusätzlich den PP-Einkommensfaktor.
/// - **A2:** Die deterministische FRT-Fehl-Attribution in der V13-Auflösung.
void main() {
  final base = DateTime(2026, 1, 1, 12);

  ProfileData oneRestaurant({
    double corruption = 0,
    bool districtLost = false,
    int budget = 10000,
    DateTime? lastSeenAt,
  }) => ProfileData(
    id: 1,
    name: 'Tester',
    creationDate: base,
    restaurants: [
      RestaurantData(
        id: 10,
        name: 'A',
        district: 'Midtown',
        budget: budget,
        corruptionPercent: corruption,
        districtLost: districtLost,
        districtLostAt: districtLost ? base : null,
        lastSeenAt: lastSeenAt ?? base,
        weekAnchorAt: lastSeenAt ?? base,
      ),
    ],
  );

  group('A0 – Persistenzpfad des ObjectProfile', () {
    test('loadFromData lädt Korruptionsfelder des aktiven Slots', () {
      final profile = ObjectProfile();
      profile.loadFromData(
        oneRestaurant(corruption: 42, districtLost: true),
        restaurantId: 10,
      );
      expect(profile.corruptionPercent, 42);
      expect(profile.districtLost, isTrue);
      expect(profile.districtLostAt, base);
    });

    test('toProfileData schreibt die Korruption auf die Platte', () {
      final profile = ObjectProfile();
      profile.loadFromData(oneRestaurant(corruption: 42), restaurantId: 10);
      final saved = profile.toProfileData();
      final slot = saved.restaurants.single;
      expect(slot.corruptionPercent, 42);
    });

    test('runCatchUp schreibt die tick-erhöhte Korruption zurück (A0-Kernbug)',
        () {
      final profile = ObjectProfile();
      profile.loadFromData(oneRestaurant(corruption: 0), restaurantId: 10);
      // Ein vollendeter 7-Tage-Block hebt die Korruption um perWeek.
      final result = profile.runCatchUp(base.add(const Duration(days: 8)));
      expect(result.weeks, greaterThanOrEqualTo(1));
      expect(
        profile.corruptionPercent,
        greaterThanOrEqualTo(FrtService.afterBlock(0)),
      );
      // Und der Wert landet auch tatsächlich in der zu speichernden Fassung.
      expect(
        profile.toProfileData().restaurants.single.corruptionPercent,
        profile.corruptionPercent,
      );
    });

    test('reduceCorruption senkt je Monster und Sieg (Floor 0)', () {
      final profile = ObjectProfile();
      profile.loadFromData(oneRestaurant(corruption: 5), restaurantId: 10);
      profile.reduceCorruption(monstersKilled: 2, victory: true);
      // 5 − 2×0.5 − 1 = 3
      expect(profile.corruptionPercent, 3);
      expect(profile.toProfileData().restaurants.single.corruptionPercent, 3);
    });

    test('reduceCorruption erholt einen verlorenen Stadtteil unter die Schwelle',
        () {
      final profile = ObjectProfile();
      profile.loadFromData(
        oneRestaurant(corruption: 100, districtLost: true),
        restaurantId: 10,
      );
      profile.reduceCorruption(victory: true);
      expect(profile.corruptionPercent, 99);
      expect(profile.districtLost, isFalse);
      expect(profile.districtLostAt, isNull);
    });

    test('reduceCorruption ohne Monster/Sieg ist ein No-op', () {
      final profile = ObjectProfile();
      profile.loadFromData(oneRestaurant(corruption: 7), restaurantId: 10);
      profile.reduceCorruption();
      expect(profile.corruptionPercent, 7);
    });

    test('Auflösung durch verlorenen Stadtteil wird persistiert (A0)', () {
      final profile = ObjectProfile();
      profile.loadFromData(oneRestaurant(corruption: 99.5), restaurantId: 10);
      profile.runCatchUp(base.add(const Duration(days: 8)));
      expect(profile.districtLost, isTrue);
      expect(profile.isDissolved, isTrue);
      final slot = profile.toProfileData().restaurants.single;
      expect(slot.districtLost, isTrue);
      expect(slot.isDissolved, isTrue);
    });
  });

  group('Q8 – Korruption mindert den PP-Einkommensfaktor', () {
    RestaurantData restaurant({double corruption = 0}) => RestaurantData(
      id: 1,
      name: 'R',
      district: 'Midtown',
      budget: 20000,
      corruptionPercent: corruption,
      lastSeenAt: base,
      weekAnchorAt: base,
    );

    test('ausgewiesener incomeFactor sinkt mit der Korruption', () {
      final clean = GameClockService.catchUp(
        restaurant(),
        base.add(const Duration(days: 8)),
      );
      final dirty = GameClockService.catchUp(
        restaurant(corruption: 50),
        base.add(const Duration(days: 8)),
      );
      expect(dirty.incomeFactor, lessThan(clean.incomeFactor));
    });

    test('ohne Korruption ist der Faktor unverändert (Q8 neutral)', () {
      final at = base.add(const Duration(days: 8));
      final result = GameClockService.catchUp(restaurant(), at);
      expect(
        result.incomeFactor,
        GameClockService.powerProjectionState(
          restaurant(),
          now: at,
        ).incomeFactor,
      );
    });
  });

  group('A2 – FRT-Fehl-Attribution (deterministisch)', () {
    RestaurantData restaurant() => RestaurantData(
      id: 1,
      name: 'R',
      district: 'Midtown',
      budget: 20000,
      lastSeenAt: base,
      weekAnchorAt: base,
    );

    test('isFrtAttack ist deterministisch', () {
      expect(
        RivalService.isFrtAttack(12345, base),
        RivalService.isFrtAttack(12345, base),
      );
    });

    test('FRT-Angreifer sind eine Teilmenge der Angreifer', () {
      final r = restaurant();
      final attackers = RivalService.incomingAttackerIds(r, base);
      final frt = RivalService.frtAttackerIds(r, base);
      for (final id in frt) {
        expect(attackers.contains(id), isTrue);
      }
    });

    test('attributedRivalId nennt einen Roster-Kollegen (deterministisch)', () {
      final r = restaurant();
      final roster = RivalService.rosterOf(r.district);
      final claimed = RivalService.attributedRivalId(r, roster.first.id, base);
      expect(roster.map((x) => x.id).contains(claimed), isTrue);
      expect(
        claimed,
        RivalService.attributedRivalId(r, roster.first.id, base),
      );
    });

    test('resolveIncomingSabotage meldet FRT-Angriffe und deren Zählung', () {
      // Über viele Blöcke: Mindestens ein Block hat einen FRT-Angriff, und die
      // unentdeckten FRT-Zählungen sind nie größer als die Gesamt-Angreifer.
      var sawFrt = false;
      for (var d = 0; d < 40; d++) {
        final anchor = base.add(Duration(days: 7 * d));
        final r = RestaurantData(
          id: 1,
          name: 'R',
          district: 'Midtown',
          budget: 20000,
          lastSeenAt: anchor,
          weekAnchorAt: anchor,
        );
        final outcome = RivalService.resolveIncomingSabotage(r, anchor);
        if (outcome == null) continue;
        expect(outcome.frtAttackerIds, RivalService.frtAttackerIds(r, anchor));
        expect(
          outcome.undetectedFrtCount,
          lessThanOrEqualTo(outcome.undetectedCount),
        );
        if (outcome.frtAttackerIds.isNotEmpty) sawFrt = true;
      }
      expect(sawFrt, isTrue);
    });

    test('unentdeckte FRT-Sabotage hebt die Korruption im Wochen-Tick', () {
      final r = restaurant();
      final frt = RivalService.resolveIncomingSabotage(r, base)?.undetectedFrtCount ?? 0;
      final result = GameClockService.catchUp(
        r,
        base.add(const Duration(days: 7)),
      );
      expect(result.weeks, 1);
      expect(
        r.corruptionPercent,
        closeTo(
          EconomyBalance.frtCorruptionPerWeekPercent +
              frt * EconomyBalance.frtCorruptionPerSabotagePercent,
          1e-9,
        ),
      );
      expect(result.frtSabotages, frt);
    });
  });
}
