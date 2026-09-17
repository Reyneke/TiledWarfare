import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/personality.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/models/stations.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/objects/player_objects/object_apprentice.dart';
import 'package:tiled_warfare/objects/player_objects/object_chef_de_partie.dart';
import 'package:tiled_warfare/objects/player_objects/object_line_cook.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/economy_service.dart';
import 'package:tiled_warfare/services/game_clock_service.dart';
import 'package:tiled_warfare/services/station_service.dart';
import 'package:tiled_warfare/utils/hex_grid.dart';

/// Stations-System für Chef de partie (Karrierepfade, V10, Phase 4):
/// Definition, Wahl/Wechsel, Kampf-Modifikatoren, Aura und Pâtissier-Refill.
void main() {
  StaffData chefStaff({String? station, int levelValue = 10}) => StaffData(
        name: 'Chef de partie: Testkoch',
        imagePath: 'x.png',
        type: kRankChefDePartie,
        rank: kRankChefDePartie,
        station: station,
        levelValue: levelValue,
        id: 77,
        personalityId: 2,
      );

  ProfileData profileWith(StaffData staff, {int budget = 10000}) => ProfileData(
        id: 7,
        name: 'Testprofil',
        creationDate: DateTime(2026, 1, 1),
        restaurants: [
          RestaurantData(id: 1, name: 'R', budget: budget, staff: [staff]),
        ],
      );

  group('Definition (V10 § 6)', () {
    test('jede Station ist bekannt, gedeckelt; Varianten haben eine Basis', () {
      for (final station in kAllStations) {
        expect(
          EconomyBalance.stationSpecs[station],
          isNotNull,
          reason: 'Fehlende Spec: $station',
        );
        for (final stat in StationStat.values) {
          expect(
            EconomyService.stationBonusPercent(station, stat).abs(),
            lessThanOrEqualTo(EconomyBalance.stationBonusMaxPercent),
          );
          expect(
            EconomyService.stationAuraPercent(station, stat).abs(),
            lessThanOrEqualTo(EconomyBalance.stationBonusMaxPercent),
          );
        }
      }
      for (final variant in kVariantStations) {
        final base = EconomyService.baseStationOf(variant);
        expect(base, isNotNull, reason: 'Variante ohne Basis: $variant');
        expect(kBaseStations, contains(base));
      }
      expect(EconomyService.isSupportStation(kStationPatissier), isTrue);
      expect(
        EconomyService.stationAuraPercent(
          kStationPatissier,
          StationStat.attack,
        ),
        0,
      );
      // Unbekannte/fehlende Stationen sind neutral.
      expect(EconomyService.stationBonusPercent(null, StationStat.attack), 0);
      expect(
        EconomyService.stationBonusPercent('gibtsnicht', StationStat.attack),
        0,
      );
    });
  });

  group('Wahl und Wechsel (ObjectProfile.assignStation)', () {
    test('ein Lehrling darf keine Station wählen', () {
      final profile = ObjectProfile();
      profile.loadFromData(
        profileWith(
          StaffData(
            name: 'Apprentice: X',
            imagePath: 'x.png',
            type: kRankApprentice,
            rank: kRankApprentice,
            levelValue: 20,
          ),
        ),
        restaurantId: 1,
      );

      expect(
        profile.assignStation(profile.personal.single, kStationSaucier),
        isFalse,
      );
      expect(profile.personal.single.station, isNull);
    });

    test('erste Wahl kostenfrei, Variante erst nach Basis, Wechsel kostet', () {
      final profile = ObjectProfile();
      profile.loadFromData(profileWith(chefStaff()), restaurantId: 1);
      final chef = profile.personal.single;
      final budgetBefore = profile.budget;

      // Variante ohne Basis-Station wird abgelehnt.
      expect(profile.assignStation(chef, kStationGrillardin), isFalse);
      expect(profile.budget, budgetBefore);
      expect(chef.station, isNull);

      // Basis-Station wählen – kostenfrei.
      expect(profile.assignStation(chef, kStationRotisseur), isTrue);
      expect(profile.budget, budgetBefore);
      expect(chef.station, kStationRotisseur);

      // Variante der gewählten Basis ist wählbar (Wechsel kostet).
      expect(profile.assignStation(chef, kStationGrillardin), isTrue);
      expect(chef.station, kStationGrillardin);
      expect(profile.budget, budgetBefore - EconomyBalance.stationSwitchCost);

      // Gleiche Station erneut: kostenfrei und erfolgreich.
      expect(profile.assignStation(chef, kStationGrillardin), isTrue);
      expect(profile.budget, budgetBefore - EconomyBalance.stationSwitchCost);
    });

    test('Wechsel unter der Negativgrenze wird abgelehnt', () {
      final profile = ObjectProfile();
      profile.loadFromData(
        profileWith(chefStaff(), budget: -19990),
        restaurantId: 1,
      );
      final chef = profile.personal.single;

      expect(profile.assignStation(chef, kStationSaucier), isTrue);
      final budgetAfterFirst = profile.budget;

      expect(profile.assignStation(chef, kStationGardeManger), isFalse);
      expect(profile.budget, budgetAfterFirst);
      expect(chef.station, kStationSaucier);
    });
  });

  group('Kampf-Modifikatoren', () {
    test('Selbstwirkung: Station erhöht den Wert, ohne Station neutral', () {
      final chef = ObjectChefDePartie()
        ..rank = kRankChefDePartie;
      final baseAttack = chef.attackValue;
      expect(chef.stationAttackBonus, 0);

      chef.station = kStationSaucier;
      expect(chef.stationAttackValue, greaterThan(baseAttack));
      expect(chef.stationAttackBonus, greaterThan(0));
      expect(
        chef.stationDefenseBonus,
        0,
        reason: 'Der Saucier wirkt auf den Angriff, nicht auf die Verteidigung',
      );
    });

    test('Aura: Verbündete im Radius werden gebufft, außerhalb nicht', () {
      const grid = HexGrid(
        tileWidth: 32,
        tileHeight: 32,
        mapWidth: 10,
        mapHeight: 10,
      );
      final chef = ObjectChefDePartie()
        ..rank = kRankChefDePartie
        ..station = kStationSaucier;
      final near = ObjectLineCook();
      final far = ObjectLineCook();

      final positions = <ObjectApprentice, ({int x, int y})>{
        chef: (x: 0, y: 0),
        near: (x: 1, y: 0), // Distanz 1 = Aura-Radius des Chef de partie
        far: (x: 5, y: 5),
      };
      StationService.applyStationAuras(
        allies: [chef, near, far],
        grid: grid,
        hexOf: (unit) => positions[unit]!,
      );

      expect(near.stationAuraAttack, greaterThan(0));
      expect(far.stationAuraAttack, 0);
      expect(
        chef.stationAuraAttack,
        0,
        reason: 'Die Selbstwirkung läuft über die Stations-Getter',
      );

      // Zieht der Verbündete weg, fällt der Aura-Bonus auf 0 (idempotent).
      positions[near] = (x: 5, y: 5);
      StationService.applyStationAuras(
        allies: [chef, near, far],
        grid: grid,
        hexOf: (unit) => positions[unit]!,
      );
      expect(near.stationAuraAttack, 0);
    });

    test('Pâtissier ist Support und verteilt keine Kampf-Aura', () {
      const grid = HexGrid(
        tileWidth: 32,
        tileHeight: 32,
        mapWidth: 10,
        mapHeight: 10,
      );
      final chef = ObjectChefDePartie()
        ..rank = kRankChefDePartie
        ..station = kStationPatissier;
      final near = ObjectLineCook();

      final positions = <ObjectApprentice, ({int x, int y})>{
        chef: (x: 0, y: 0),
        near: (x: 1, y: 0),
      };
      StationService.applyStationAuras(
        allies: [chef, near],
        grid: grid,
        hexOf: (unit) => positions[unit]!,
      );

      expect(near.stationAuraAttack, 0);
      expect(near.stationAuraDefense, 0);
      expect(near.stationAuraDamage, 0);
    });
  });

  group('Wochen-Refill (V10 § 2)', () {
    final start = DateTime(2026, 1, 1);

    RestaurantData refillRestaurant({required bool withPatissier}) =>
        RestaurantData(
          id: 1,
          name: 'R',
          budget: 10000,
          district: 'Harlem',
          lastSeenAt: start,
          weekAnchorAt: start,
          staff: [
            if (withPatissier)
              StaffData(
                name: 'Pâtissier',
                imagePath: 'x.png',
                type: kRankChefDePartie,
                rank: kRankChefDePartie,
                station: kStationPatissier,
                id: 111,
                personalityId: 2,
              ),
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

    test('Pâtissier verbessert den Refill der Kollegen, nicht den eigenen', () {
      final restaurant = refillRestaurant(withPatissier: true);
      GameClockService.catchUp(restaurant, start.add(const Duration(days: 7)));

      int boosted(int value) => (value *
              (100 + EconomyBalance.patissierRefillBonusPercent) /
              100)
          .round()
          .clamp(EconomyBalance.resourceMin, EconomyBalance.resourceMax);

      final cookTraits = PersonalityTraits.forProfile(2, 4251);
      final cook = restaurant.staff.last;
      expect(cook.vitalityCurrent, boosted(cookTraits.vitality));
      expect(cook.moraleCurrent, boosted(cookTraits.morale));

      // Die Support-Station profitiert nicht von ihrer eigenen Wirkung.
      final patissierTraits = PersonalityTraits.forProfile(2, 111);
      expect(restaurant.staff.first.vitalityCurrent, patissierTraits.vitality);
      expect(restaurant.staff.first.moraleCurrent, patissierTraits.morale);
    });

    test('ohne Pâtissier bleibt der Refill der Trait-Basiswert', () {
      final restaurant = refillRestaurant(withPatissier: false);
      GameClockService.catchUp(restaurant, start.add(const Duration(days: 7)));

      final traits = PersonalityTraits.forProfile(2, 4251);
      expect(restaurant.staff.single.vitalityCurrent, traits.vitality);
      expect(restaurant.staff.single.moraleCurrent, traits.morale);
    });
  });
}
