import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/economy_service.dart';

/// Tests für den Personal-Transfer samt erweitertem Merging (Karrierepfade,
/// V10): Das nicht-aktive Ziel-Restaurant wird beim nächsten Speichervorgang
/// mitgeschrieben, statt die übrigen Spielstände unverändert zu lassen.
ProfileData _twoRestaurants({
  int budgetA = 10000,
  int budgetB = 10000,
  bool dissolvedB = false,
}) =>
    ProfileData(
      id: 1,
      name: 'Tester',
      creationDate: DateTime(2026, 1, 1),
      restaurants: [
        RestaurantData(id: 10, name: 'A', budget: budgetA),
        RestaurantData(
          id: 20,
          name: 'B',
          budget: budgetB,
          isDissolved: dissolvedB,
        ),
      ],
    );

void main() {
  test('Transfer verschiebt Personal beim nächsten Speichern ins Ziel (V10)',
      () {
    final profile = ObjectProfile();
    profile.loadFromData(_twoRestaurants(), restaurantId: 10);
    expect(
      profile.hireApprentice(random: Random(1), now: DateTime(2026, 1, 1, 8)),
      isTrue,
    );
    final staff = profile.personal.single;
    final cost = EconomyService.transferCost(level: staff.levelValue);
    final staffId = staff.id;

    expect(
      profile.transferStaff(staff: staff, targetRestaurantId: 20),
      isTrue,
    );
    // Quelle verliert den Charakter sofort (In-Memory-Zustand).
    expect(profile.personal, isEmpty);

    final saved = profile.toProfileData();
    final a = saved.restaurants.firstWhere((r) => r.id == 10);
    final b = saved.restaurants.firstWhere((r) => r.id == 20);

    expect(a.staff, isEmpty);
    expect(b.staff, hasLength(1));
    expect(b.staff.single.id, staffId); // Identität erhalten
    expect(b.budget, 10000 - cost); // Ziel zahlt
    // Die Quelle zahlt nur die Anheuerung, nicht den Transfer.
    expect(a.budget, 10000 - EconomyBalance.hireApprenticeCost);
  });

  test('Transfer wird abgelehnt, wenn das Ziel die Kosten nicht tragen kann',
      () {
    final profile = ObjectProfile();
    profile.loadFromData(
      _twoRestaurants(budgetB: EconomyBalance.negativeLimit),
      restaurantId: 10,
    );
    profile.hireApprentice(random: Random(1), now: DateTime(2026, 1, 1, 8));
    final staff = profile.personal.single;

    expect(
      profile.transferStaff(staff: staff, targetRestaurantId: 20),
      isFalse,
    );
    expect(profile.personal, hasLength(1)); // Zustand unverändert
  });

  test('Transfer in unbekanntes, aufgelöstes oder aktives Ziel wird abgelehnt',
      () {
    final profile = ObjectProfile();
    profile.loadFromData(
      _twoRestaurants(dissolvedB: true),
      restaurantId: 10,
    );
    profile.hireApprentice(random: Random(1), now: DateTime(2026, 1, 1, 8));
    final staff = profile.personal.single;

    expect(
      profile.transferStaff(staff: staff, targetRestaurantId: 999),
      isFalse,
    );
    expect(
      profile.transferStaff(staff: staff, targetRestaurantId: 20),
      isFalse,
    );
    expect(
      profile.transferStaff(staff: staff, targetRestaurantId: 10),
      isFalse,
    );
    expect(profile.personal, hasLength(1));
  });

  test('Der Transfer wird beim Speichern nur einmal angewendet (V10)', () {
    final profile = ObjectProfile();
    profile.loadFromData(_twoRestaurants(), restaurantId: 10);
    profile.hireApprentice(random: Random(1), now: DateTime(2026, 1, 1, 8));
    final staff = profile.personal.single;
    final cost = EconomyService.transferCost(level: staff.levelValue);

    expect(profile.transferStaff(staff: staff, targetRestaurantId: 20), isTrue);

    final first = profile.toProfileData();
    final second = profile.toProfileData();
    final firstB = first.restaurants.firstWhere((r) => r.id == 20);
    final secondB = second.restaurants.firstWhere((r) => r.id == 20);

    expect(firstB.staff, hasLength(1));
    expect(firstB.budget, 10000 - cost);
    // Zweiter Aufruf wendet die (nun verbrauchte) Änderung nicht erneut an.
    expect(secondB.staff, hasLength(1));
    expect(secondB.budget, 10000 - cost);
  });

  test('Zwei Transfers auf dasselbe Ziel stapeln Kosten und Personal (V10)', () {
    final profile = ObjectProfile();
    profile.loadFromData(_twoRestaurants(), restaurantId: 10);
    profile.hireApprentice(random: Random(1), now: DateTime(2026, 1, 1, 8));
    profile.hireApprentice(random: Random(2), now: DateTime(2026, 1, 1, 9));
    final staff = profile.personal.toList();
    final cost = EconomyService.transferCost(level: staff.first.levelValue);

    expect(
      profile.transferStaff(staff: staff[0], targetRestaurantId: 20),
      isTrue,
    );
    expect(
      profile.transferStaff(staff: staff[1], targetRestaurantId: 20),
      isTrue,
    );

    final saved = profile.toProfileData();
    final b = saved.restaurants.firstWhere((r) => r.id == 20);
    expect(b.staff, hasLength(2));
    expect(b.budget, 10000 - 2 * cost);
  });
}
