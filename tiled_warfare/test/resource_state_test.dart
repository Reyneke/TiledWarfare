import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/management_feature.dart';
import 'package:tiled_warfare/models/management_role.dart';
import 'package:tiled_warfare/models/medic_quality.dart';
import 'package:tiled_warfare/models/personality.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/models/restaurant_upgrade.dart';
import 'package:tiled_warfare/models/staff_entry.dart';
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
    Map<UpgradeType, int>? upgrades,
    List<StaffEntryData>? entries,
    List<StaffData>? staff,
  }) =>
      RestaurantData(
        id: 1,
        name: 'Testrestaurant',
        budget: 10000,
        district: 'Harlem',
        lastSeenAt: start,
        weekAnchorAt: start,
        upgrades: upgrades,
        staffEntries: entries,
        staff: staff ??
            [
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

  group('Ruheraum/Lounge (V1-Paket, § 10)', () {
    StaffEntryData chief() => StaffEntryData(
          id: 3, // competenceOf(3) == 4 ⇒ −4 × 6 % = −24 % Sink.
          name: 'Gewerkschaftschef',
          kind: RoleKind.management,
          role: ManagementRole.unionChief.name,
          costPerWeek:
              EconomyBalance.managementRoleWagePerWeek[ManagementRole
                  .unionChief]!,
        );

    StaffEntryData storekeeper() => StaffEntryData(
          id: 1,
          name: 'Lagerist',
          kind: RoleKind.management,
          role: ManagementRole.storekeeper.name,
          costPerWeek:
              EconomyBalance.managementRoleWagePerWeek[ManagementRole
                  .storekeeper]!,
          activeFeature: ManagementFeature.storageTetris.name,
          featureActivatedAt: start,
        );

    test('hebt den Wochen-Refill je Stufe (Stufe 3 = +9 %)', () {
      final base = PersonalityTraits.forProfile(2, 4251);
      int boosted(int value) => (value * 109 / 100)
          .round()
          .clamp(EconomyBalance.resourceMin, EconomyBalance.resourceMax);

      final plain = restaurant();
      final rested = restaurant(upgrades: const {UpgradeType.lounge: 3});
      GameClockService.catchUp(plain, start.add(const Duration(days: 7)));
      GameClockService.catchUp(rested, start.add(const Duration(days: 7)));

      // Referenz: der Refill landet (wie ohne Erweiterung) auf dem Trait-Wert.
      expect(plain.staff.single.vitalityCurrent, base.vitality);
      expect(plain.staff.single.moraleCurrent, base.morale);

      // Mit Ruheraum: +9 % auf den Basiswert (gerundet, auf 0–100 gedeckelt).
      expect(rested.staff.single.vitalityCurrent, boosted(base.vitality));
      expect(rested.staff.single.moraleCurrent, boosted(base.morale));
    });

    test('der Refill-Bonus ist linear mit der Stufe', () {
      int refilled(int level) {
        final r = restaurant(upgrades: {UpgradeType.lounge: level});
        GameClockService.catchUp(r, start.add(const Duration(days: 7)));
        return r.staff.single.vitalityCurrent!;
      }

      // Dieselbe Rundung wie `GameClockService._withRefillBonus`.
      final base = PersonalityTraits.forProfile(2, 4251).vitality;
      int boosted(int percent) => (base * (100 + percent) / 100)
          .round()
          .clamp(EconomyBalance.resourceMin, EconomyBalance.resourceMax);

      expect(refilled(1), boosted(3));
      expect(refilled(2), boosted(6));
      expect(refilled(3), boosted(9));
      // Ohne Stufe bleibt es der unveränderte Trait-Wert.
      expect(refilled(0), base);
    });

    test('senkt den Tages-Sink additiv zum Gewerkschaftschef', () {
      // Gewerkschaftschef (Kompetenz 4) allein: −24 % ⇒ 5 × 76 % = 3,8 → 4/Tag.
      // Mit Ruheraum-Stufe 3 (−9 %) sind es −33 % ⇒ 5 × 67 % = 3,35 → 3/Tag.
      final plain = restaurant(entries: [chief()]);
      final rested = restaurant(
        entries: [chief()],
        upgrades: const {UpgradeType.lounge: 3},
      );
      GameClockService.catchUp(plain, start.add(const Duration(days: 3)));
      GameClockService.catchUp(rested, start.add(const Duration(days: 3)));

      expect(plain.staff.single.vitalityCurrent, 80 - 3 * 4);
      expect(plain.staff.single.moraleCurrent, 60 - 3 * 4);
      expect(rested.staff.single.vitalityCurrent, 80 - 3 * 3);
      expect(rested.staff.single.moraleCurrent, 60 - 3 * 3);
    });

    test('unter dem Rundungs-Radar bleibt der Sink allein unverändert', () {
      // 5 × 91 % = 4,55 → 5: Die Sink-Seite ist bewusst ein Stacking-Hebel
      // (§ 10) und wirkt erst mit dem Gewerkschaftschef – oder in der
      // Nachteilphase eines Features mit Sink-Faktor 2.
      final plain = restaurant();
      final rested = restaurant(upgrades: const {UpgradeType.lounge: 3});
      GameClockService.catchUp(plain, start.add(const Duration(days: 3)));
      GameClockService.catchUp(rested, start.add(const Duration(days: 3)));

      expect(
        rested.staff.single.vitalityCurrent,
        plain.staff.single.vitalityCurrent,
      );
      expect(rested.staff.single.moraleCurrent, plain.staff.single.moraleCurrent);
    });

    test('die Erleichterung bleibt gedeckelt – „Mali entfallen“ heilt nicht', () {
      // Lagertetris setzt die Relief bereits auf 100 %; der Ruheraum darf die
      // Summe nicht darüber heben, sonst würde der Sink negativ („Heilung“).
      final r = restaurant(
        entries: [storekeeper()],
        upgrades: const {UpgradeType.lounge: 3},
      );
      GameClockService.catchUp(r, start.add(const Duration(days: 3)));

      expect(r.staff.single.vitalityCurrent, 80);
      expect(r.staff.single.moraleCurrent, 60);
    });

    test('berührt keinen der drei Eingangswerte (§ 8)', () {
      final plain = restaurant();
      final rested = restaurant(upgrades: const {UpgradeType.lounge: 3});
      expect(
        GameClockService.attractivenessOf(rested),
        GameClockService.attractivenessOf(plain),
      );
      expect(
        GameClockService.satisfactionOf(rested),
        GameClockService.satisfactionOf(plain),
      );
      expect(
        GameClockService.capacityOf(rested),
        GameClockService.capacityOf(plain),
      );
    });

    test('Unterhalt wird im Wochenblock abgebucht (Stufe 3 × 18 €)', () {
      final r = restaurant(upgrades: const {UpgradeType.lounge: 3});
      final result = GameClockService.catchUp(
        r,
        start.add(const Duration(days: 7)),
      );

      expect(result.weeks, 1);
      expect(result.settlements.single.upgradeUpkeep, 54);
    });
  });
}