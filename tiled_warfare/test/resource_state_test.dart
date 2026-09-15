import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/medic_quality.dart';
import 'package:tiled_warfare/models/personality.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/economy_service.dart';
import 'package:tiled_warfare/services/game_clock_service.dart';

/// Ressourcen (Vitalität/Moral) und Lohnfaktor – Phase 3, V9
/// (`doc/todo/feat_better_restaurant_management/9_Personal.md`).
void main() {
  final start = DateTime(2026, 1, 1);

  RestaurantData restaurant({
    int vitality = 80,
    int morale = 60,
    int personalityId = 2,
    int charId = 4251,
  }) =>
      RestaurantData(
        id: 1,
        name: 'Testrestaurant',
        budget: 10000,
        district: 'Harlem',
        lastSeenAt: start,
        weekAnchorAt: start,
        staff: [
          StaffData(
            name: 'Koch',
            imagePath: 'x.png',
            type: 'apprentice',
            id: charId,
            personalityId: personalityId,
            vitalityCurrent: vitality,
            moraleCurrent: morale,
          ),
        ],
      );

  test('Tages-Sink: −5 je Echtzeit-Tag und idempotent im Catch-up', () {
    final r = restaurant();
    GameClockService.catchUp(r, start.add(const Duration(days: 3)));
    expect(
      r.staff.single.vitalityCurrent,
      80 - 3 * EconomyBalance.resourceSinkPerDay,
    );
    expect(
      r.staff.single.moraleCurrent,
      60 - 3 * EconomyBalance.resourceSinkPerDay,
    );

    // Zweiter Aufruf mit demselben now: keine weitere Buchung.
    GameClockService.catchUp(r, start.add(const Duration(days: 3)));
    expect(r.staff.single.vitalityCurrent, 65);
  });

  test('Sink klemmt auf 0', () {
    final r = restaurant(vitality: 8, morale: 3);
    GameClockService.catchUp(r, start.add(const Duration(days: 3)));
    expect(r.staff.single.vitalityCurrent, 0);
    expect(r.staff.single.moraleCurrent, 0);
  });

  test('Wochen-Refill: am Block-Ende zurück auf den Trait-Basiswert', () {
    final r = restaurant();
    GameClockService.catchUp(r, start.add(const Duration(days: 7)));
    final base = PersonalityTraits.forProfile(2, 4251);
    expect(r.staff.single.vitalityCurrent, base.vitality);
    expect(r.staff.single.moraleCurrent, base.morale);
  });

  test('Einsatz-Sink: −10 je Gefecht über syncUnitsAfterBattle', () {
    final profile = ObjectProfile();
    profile.loadFromData(
      ProfileData(
        id: 7,
        name: 'Testprofil',
        creationDate: start,
        restaurants: [
          RestaurantData(
            id: 1,
            name: 'Testrestaurant',
            budget: 10000,
            staff: [
              StaffData(
                name: 'Apprentice: K',
                imagePath: 'x.png',
                type: 'apprentice',
                id: 99,
                personalityId: 3,
                vitalityCurrent: 70,
                moraleCurrent: 60,
              ),
            ],
          ),
        ],
      ),
      restaurantId: 1,
    );
    final survivor = profile.personal.single;
    profile.syncUnitsAfterBattle([survivor], random: Random(4), now: start);

    expect(survivor.vitalityCurrent, 60);
    expect(survivor.moraleCurrent, 50);
  });

  test('Hilfsbereitschaft erhöht die Attraktivität (Phase 3)', () {
    final withPersonality = GameClockService.attractivenessOf(restaurant());
    final legacy = GameClockService.attractivenessOf(restaurant(personalityId: -1));
    final avg = PersonalityTraits.forProfile(2, 4251).helpfulness.toDouble();
    expect(
      withPersonality - legacy,
      closeTo(EconomyBalance.personalityAttractivenessWeight * avg, 1e-6),
    );
  });

  test('Thriftiness verschiebt die Wochenkosten (±Spread, 50 = neutral)', () {
    final spendierer = EconomyService.weeklyMedicCost(MedicQuality.hoch, 1, 0);
    final neutral = EconomyService.weeklyMedicCost(MedicQuality.hoch, 1, 50);
    final sparsamer = EconomyService.weeklyMedicCost(MedicQuality.hoch, 1, 100);
    expect(spendierer, greaterThan(neutral));
    expect(sparsamer, lessThan(neutral));
    expect(neutral, EconomyService.weeklyMedicCost(MedicQuality.hoch, 1));
  });
}