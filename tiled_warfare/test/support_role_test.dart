import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/personality.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/models/restaurant_upgrade.dart';
import 'package:tiled_warfare/models/support_role.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/game_clock_service.dart';
import 'package:tiled_warfare/services/support_role_service.dart';

/// Tests der Hilfs-/Service-Rollen (Karrierepfade, V10, Phase 6):
/// Persistenz, Verwaltung und Wirkung auf die Management-Schleife.
void main() {
  final start = DateTime(2026, 1, 1);

  SupportRoleData role(SupportRole type) =>
      SupportRoleData(id: 1, name: 'X', role: type.name, costPerWeek: 100);

  test('SupportRoleData serialisiert und liest tolerant (V6/V10)', () {
    final entry = SupportRoleData(
      id: 5,
      name: 'Luigi',
      role: 'communard',
      costPerWeek: 150,
      hiredAt: start,
    );
    final restored = SupportRoleData.fromJson(entry.toJson());
    expect(restored.id, 5);
    expect(restored.role, 'communard');
    expect(restored.costPerWeek, 150);
    expect(restored.hiredAt, start);

    final legacy = SupportRoleData.fromJson({'name': 'Alt'});
    expect(legacy.role, '');
    expect(legacy.costPerWeek, 0);
    expect(legacy.hiredAt, isNull);
  });

  test('kProfileSchemaVersion ist 8 (Verwaltungsrollen + Rivalen-Modul)', () {
    expect(kProfileSchemaVersion, 8);
  });

  test('RestaurantData persistiert supportStaff auch über copyWith', () {
    final restaurant = RestaurantData(
      id: 1,
      name: 'R',
      supportStaff: [
        SupportRoleData(id: 1, name: 'A', role: 'plongeur', costPerWeek: 70),
      ],
    );

    final restored = RestaurantData.fromJson(restaurant.toJson());
    expect(restored.supportStaff.single.role, 'plongeur');

    // Der Merge-Pfad (Personal-Transfer) darf die Rollen nicht verlieren.
    expect(restaurant.copyWith(budget: 1).supportStaff, hasLength(1));
  });

  test('ObjectProfile: einstellen, speichern, entlassen', () {
    final profile = ObjectProfile();
    profile.loadFromData(
      ProfileData(
        id: 7,
        name: 'P',
        creationDate: start,
        restaurants: [RestaurantData(id: 1, name: 'R', budget: 10000)],
      ),
      restaurantId: 1,
    );

    final entry = profile.hireSupportRole(SupportRole.aboyeur, now: start);
    expect(profile.supportStaffCount, 1);
    expect(entry.role, 'aboyeur');
    expect(
      entry.costPerWeek,
      EconomyBalance.supportRoleWagePerWeek[SupportRole.aboyeur],
    );

    final saved = profile.toProfileData();
    expect(saved.restaurants.single.supportStaff.single.role, 'aboyeur');

    profile.fireSupportRole(profile.supportStaff.single);
    expect(profile.supportStaffCount, 0);
  });

  test('unbekannte Rollen werden beim Laden übersprungen', () {
    final profile = ObjectProfile();
    profile.loadFromData(
      ProfileData(
        id: 7,
        name: 'P',
        creationDate: start,
        restaurants: [
          RestaurantData(
            id: 1,
            name: 'R',
            supportStaff: [
              SupportRoleData(
                  id: 1, name: 'A', role: 'plongeur', costPerWeek: 70),
              SupportRoleData(
                  id: 2, name: 'X', role: 'gibtsnicht', costPerWeek: 1),
            ],
          ),
        ],
      ),
      restaurantId: 1,
    );
    expect(profile.supportStaffCount, 1);
    expect(profile.supportStaff.single.role, 'plongeur');
  });

  test('jede Rolle hat einen Wochenlohn', () {
    for (final type in kAllSupportRoles) {
      expect(
        EconomyBalance.supportRoleWagePerWeek[type],
        greaterThan(0),
        reason: 'Fehlender Lohn: $type',
      );
    }
  });

  group('Wirkung auf die Management-Schleife', () {
    RestaurantData restaurant({
      List<SupportRoleData> support = const [],
      Map<UpgradeType, int>? upgrades,
    }) =>
        RestaurantData(
          id: 1,
          name: 'R',
          budget: 10000,
          district: 'Harlem',
          lastSeenAt: start,
          weekAnchorAt: start,
          supportStaff: support,
          upgrades: upgrades,
          staff: [
            StaffData(
              name: 'Koch',
              imagePath: 'x.png',
              type: kRankApprentice,
              rank: kRankApprentice,
              id: 4251,
              personalityId: 2,
            ),
          ],
        );

    test('Communard verbessert den Wochen-Refill der Kollegen', () {
      final plain = restaurant();
      final boosted = restaurant(support: [role(SupportRole.communard)]);
      GameClockService.catchUp(plain, start.add(const Duration(days: 7)));
      GameClockService.catchUp(boosted, start.add(const Duration(days: 7)));

      final traits = PersonalityTraits.forProfile(2, 4251);
      expect(plain.staff.single.vitalityCurrent, traits.vitality);
      expect(
        boosted.staff.single.vitalityCurrent,
        greaterThanOrEqualTo(traits.vitality),
      );
      expect(
        SupportRoleService.refillBonusPercent(boosted.supportStaff),
        EconomyBalance.communardRefillBonusPercent,
      );
      expect(SupportRoleService.refillBonusPercent(const []), 0);
    });

    test('Aboyeur erhöht das passive Einkommen (und kostet Lohn)', () {
      final plain = restaurant();
      final boosted = restaurant(support: [role(SupportRole.aboyeur)]);
      final without =
          GameClockService.catchUp(plain, start.add(const Duration(days: 7)));
      final withRole =
          GameClockService.catchUp(boosted, start.add(const Duration(days: 7)));

      expect(withRole.passiveIncome, greaterThan(without.passiveIncome));
      expect(withRole.staffCosts, greaterThan(without.staffCosts));
    });

    test('Plongeur senkt den Erweiterungs-Unterhalt', () {
      final upgrades = {UpgradeType.signage: 3};
      final plain = restaurant(upgrades: Map.of(upgrades));
      final boosted = restaurant(
        support: [role(SupportRole.plongeur)],
        upgrades: Map.of(upgrades),
      );
      final without =
          GameClockService.catchUp(plain, start.add(const Duration(days: 7)));
      final withRole =
          GameClockService.catchUp(boosted, start.add(const Duration(days: 7)));

      expect(without.upgradeUpkeep, greaterThan(0));
      expect(withRole.upgradeUpkeep, lessThan(without.upgradeUpkeep));
    });

    test('Commis und Garçon heben Attraktivität und Zufriedenheit', () {
      final plain = restaurant();
      final boosted = restaurant(
        support: [role(SupportRole.commis), role(SupportRole.garcon)],
      );

      expect(
        SupportRoleService.attractivenessBonus(boosted.supportStaff),
        greaterThan(0),
      );
      expect(
        GameClockService.attractivenessOf(boosted),
        greaterThanOrEqualTo(GameClockService.attractivenessOf(plain)),
      );
      expect(
        SupportRoleService.satisfactionBonus(boosted.supportStaff),
        greaterThan(0),
      );
      expect(
        GameClockService.satisfactionOf(boosted),
        greaterThanOrEqualTo(GameClockService.satisfactionOf(plain)),
      );
    });

    test('Boucher erhöht die Beute, Tournant senkt den Erschöpfungs-Malus', () {
      expect(
        SupportRoleService.lootPercent([role(SupportRole.boucher)]),
        EconomyBalance.boucherLootPercent,
      );
      expect(SupportRoleService.lootPercent(const []), 0);
      expect(
        SupportRoleService.exhaustionReliefPercent(
            [role(SupportRole.tournant)]),
        EconomyBalance.tournantExhaustionReliefPercent,
      );
      expect(SupportRoleService.exhaustionReliefPercent(const []), 0);
    });

    test('Support-Löhne summieren sich', () {
      expect(
        SupportRoleService.weeklyWages([
          role(SupportRole.commis),
          role(SupportRole.garcon),
        ]),
        200,
      );
    });
  });
}
