import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/objects/player_objects/object_head_chef.dart';
import 'package:tiled_warfare/objects/player_objects/object_sous_chef.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/economy_service.dart';
import 'package:tiled_warfare/services/game_clock_service.dart';

/// Tests der Ränge `Sous-chef`/`Chef de cuisine` samt Doppelrolle,
/// Unikat-Invariante und Nachrücken (Karrierepfade, V10, Phase 5).
void main() {
  ProfileData profileWith(
          {required List<StaffData> staff, int budget = 30000}) =>
      ProfileData(
        id: 7,
        name: 'Testprofil',
        creationDate: DateTime(2026, 1, 1),
        restaurants: [
          RestaurantData(
            id: 1,
            name: 'Testrestaurant',
            budget: budget,
            staff: staff,
          ),
        ],
      );

  StaffData staffData({
    required String rank,
    int levelValue = 20,
    String? headChefRole,
    int? assignedRestaurantId,
    int id = 42,
    int personalityId = 2,
  }) =>
      StaffData(
        name: 'Apprentice: Testkoch',
        imagePath: 'x.png',
        type: rank,
        rank: rank,
        levelValue: levelValue,
        headChefRole: headChefRole,
        assignedRestaurantId: assignedRestaurantId,
        id: id,
        personalityId: personalityId,
      );

  group('Aufstiegsleiter bis zum Chef de cuisine', () {
    test('Kette und Kosten: CDP → Sous-chef → Chef de cuisine', () {
      expect(EconomyService.nextRank(kRankChefDePartie), kRankSousChef);
      expect(EconomyService.nextRank(kRankSousChef), kRankHeadChef);
      expect(EconomyService.nextRank(kRankHeadChef), isNull);
      expect(
        EconomyService.promotionCost(kRankSousChef),
        EconomyBalance.upgradeToSousChefCost,
      );
      expect(
        EconomyService.promotionCost(kRankHeadChef),
        EconomyBalance.upgradeToHeadChefCost,
      );
    });

    test('Sous-chef: eigene Klasse, Level-Gate 15, Kosten 3000', () {
      final tooLow = ObjectProfile();
      tooLow.loadFromData(
        profileWith(
          staff: [staffData(rank: kRankChefDePartie, levelValue: 14)],
        ),
        restaurantId: 1,
      );
      expect(
        tooLow.promoteToRank(tooLow.personal.single, kRankSousChef),
        isNull,
      );

      final profile = ObjectProfile();
      profile.loadFromData(
        profileWith(
          staff: [staffData(rank: kRankChefDePartie, levelValue: 15)],
        ),
        restaurantId: 1,
      );
      final budgetBefore = profile.budget;
      final promoted =
          profile.promoteToRank(profile.personal.single, kRankSousChef)!;

      expect(promoted, isA<ObjectSousChef>());
      expect(promoted.rank, kRankSousChef);
      expect(profile.budget, budgetBefore - EconomyBalance.upgradeToSousChefCost);
      expect(promoted.name, 'Sous-chef: Testkoch');
    });

    test('Chef de cuisine: eigene Klasse, Level-Gate 20, Kosten 8000', () {
      final profile = ObjectProfile();
      profile.loadFromData(
        profileWith(staff: [staffData(rank: kRankSousChef, levelValue: 20)]),
        restaurantId: 1,
      );
      final budgetBefore = profile.budget;
      final promoted =
          profile.promoteToRank(profile.personal.single, kRankHeadChef)!;

      expect(promoted, isA<ObjectHeadChef>());
      expect(promoted.rank, kRankHeadChef);
      expect(
        profile.budget,
        budgetBefore - EconomyBalance.upgradeToHeadChefCost,
      );
      expect(promoted.name, 'Chef de cuisine: Testkoch');
    });

    test('Beförderung überschreitet die Unikat-Invariante nicht (formell)', () {
      final profile = ObjectProfile();
      profile.loadFromData(
        profileWith(
          staff: [
            staffData(rank: kRankSousChef, levelValue: 20),
            staffData(
              rank: kRankHeadChef,
              id: 43,
              headChefRole: kHeadChefRoleActive,
              assignedRestaurantId: 1,
            ),
          ],
        ),
        restaurantId: 1,
      );

      final promoted = profile.promoteToRank(
        profile.personal.firstWhere((c) => c.rank == kRankSousChef),
        kRankHeadChef,
      );

      expect(promoted!.headChefRole, kHeadChefRoleFormal);
      expect(promoted.assignedRestaurantId, isNull);
      // Der bisherige aktive Chef bleibt zugeteilt.
      expect(profile.activeHeadChef()!.id, 43);
    });

    test('Rang und Doppelrolle überleben Speichern und Laden', () {
      final profile = ObjectProfile();
      profile.loadFromData(
        profileWith(staff: [staffData(rank: kRankSousChef, levelValue: 20)]),
        restaurantId: 1,
      );
      final promoted =
          profile.promoteToRank(profile.personal.single, kRankHeadChef)!;
      expect(profile.assignHeadChef(promoted), isTrue);

      final saved = profile.toProfileData();
      final savedStaff = saved.restaurants.single.staff.single;
      expect(savedStaff.rank, kRankHeadChef);
      expect(savedStaff.headChefRole, kHeadChefRoleActive);
      expect(savedStaff.assignedRestaurantId, 1);

      profile.loadFromData(saved, restaurantId: 1);
      final reloaded = profile.personal.single;
      expect(reloaded, isA<ObjectHeadChef>());
      expect(reloaded.headChefRole, kHeadChefRoleActive);
      expect(reloaded.assignedRestaurantId, 1);
      expect(profile.activeHeadChef(), isNotNull);
    });
  });

  group('Zuteilung und Nachrücken', () {
    test('nur ein aktiver Chef pro Restaurant (Unikat-Invariante)', () {
      final profile = ObjectProfile();
      profile.loadFromData(
        profileWith(
          staff: [
            staffData(rank: kRankHeadChef, id: 1),
            staffData(rank: kRankHeadChef, id: 2),
          ],
        ),
        restaurantId: 1,
      );

      final chefs = profile.personal;
      expect(profile.assignHeadChef(chefs[0]), isTrue);
      expect(profile.assignHeadChef(chefs[1]), isFalse);
      expect(profile.activeHeadChef(), same(chefs[0]));
      expect(chefs[1].headChefRole, isNot(kHeadChefRoleActive));
    });

    test('kein aktiver Chef für andere Ränge', () {
      final profile = ObjectProfile();
      profile.loadFromData(
        profileWith(staff: [staffData(rank: kRankSousChef)]),
        restaurantId: 1,
      );
      expect(profile.assignHeadChef(profile.personal.single), isFalse);
    });

    test('Kandidatenliste: höchstes Level, dann kleinste ID', () {
      final profile = ObjectProfile();
      profile.loadFromData(
        profileWith(
          staff: [
            staffData(rank: kRankHeadChef, id: 99, levelValue: 20),
            staffData(rank: kRankHeadChef, id: 7, levelValue: 25),
            staffData(rank: kRankHeadChef, id: 3, levelValue: 25),
          ],
        ),
        restaurantId: 1,
      );

      final candidates = profile.formalHeadChefCandidates();
      expect(candidates.map((c) => c.id).toList(), [3, 7, 99]);
      expect(profile.nachrueckenHeadChef()!.id, 3);
    });

    test('Nachrücken nach Entlassung des aktiven Chefs', () {
      final profile = ObjectProfile();
      profile.loadFromData(
        profileWith(
          staff: [
            staffData(
              rank: kRankHeadChef,
              id: 1,
              headChefRole: kHeadChefRoleActive,
              assignedRestaurantId: 1,
            ),
            staffData(rank: kRankHeadChef, id: 2, levelValue: 30),
          ],
        ),
        restaurantId: 1,
      );

      profile.fireCharacter(profile.activeHeadChef()!);

      final next = profile.activeHeadChef();
      expect(next, isNotNull);
      expect(next!.id, 2);
      expect(next.headChefRole, kHeadChefRoleActive);
      expect(next.assignedRestaurantId, 1);
    });

    test('kein Nachrücken, solange der Posten besetzt ist', () {
      final profile = ObjectProfile();
      profile.loadFromData(
        profileWith(
          staff: [
            staffData(
              rank: kRankHeadChef,
              id: 1,
              headChefRole: kHeadChefRoleActive,
              assignedRestaurantId: 1,
            ),
            staffData(rank: kRankHeadChef, id: 2),
          ],
        ),
        restaurantId: 1,
      );
      expect(profile.nachrueckenHeadChef(), isNull);
    });
  });

  group('Management-Profil', () {
    test('aktiver Chef bufft Attraktivität, Zufriedenheit und Kapazität', () {
      final start = DateTime(2026, 1, 1);
      RestaurantData restaurant({String? role}) => RestaurantData(
            id: 1,
            name: 'R',
            budget: 10000,
            district: 'Harlem',
            lastSeenAt: start,
            weekAnchorAt: start,
            staff: [
              StaffData(
                name: 'Chef',
                imagePath: 'x.png',
                type: kRankHeadChef,
                rank: kRankHeadChef,
                headChefRole: role,
                assignedRestaurantId: role == kHeadChefRoleActive ? 1 : null,
                id: 5,
                // Ohne Persönlichkeit bleibt die Attraktivität unter dem Deckel
                // (`inputDomainMax`), sodass der Buff messbar ist.
                personalityId: -1,
                levelValue: 25,
              ),
            ],
          );

      final formal = restaurant(role: kHeadChefRoleFormal);
      final active = restaurant(role: kHeadChefRoleActive);

      expect(GameClockService.hasActiveHeadChef(formal), isFalse);
      expect(GameClockService.hasActiveHeadChef(active), isTrue);
      expect(
        GameClockService.attractivenessOf(active),
        greaterThan(GameClockService.attractivenessOf(formal)),
      );
      expect(
        GameClockService.satisfactionOf(active),
        greaterThan(GameClockService.satisfactionOf(formal)),
      );
      expect(
        GameClockService.capacityOf(active),
        greaterThan(GameClockService.capacityOf(formal)),
      );
    });
  });

  group('Personal-Transfer (Phase 8)', () {
    test('aktiver Chef: Ziel wird formell, in der Quelle rückt einer nach', () {
      final profile = ObjectProfile();
      profile.loadFromData(
        ProfileData(
          id: 7,
          name: 'P',
          creationDate: DateTime(2026, 1, 1),
          restaurants: [
            RestaurantData(
              id: 10,
              name: 'A',
              budget: 10000,
              staff: [
                StaffData(
                  name: 'Chef A',
                  imagePath: 'x.png',
                  type: kRankHeadChef,
                  rank: kRankHeadChef,
                  headChefRole: kHeadChefRoleActive,
                  assignedRestaurantId: 10,
                  id: 1,
                  personalityId: 2,
                  levelValue: 25,
                ),
                StaffData(
                  name: 'Chef B',
                  imagePath: 'x.png',
                  type: kRankHeadChef,
                  rank: kRankHeadChef,
                  id: 2,
                  personalityId: 2,
                  levelValue: 22,
                ),
              ],
            ),
            RestaurantData(id: 20, name: 'B', budget: 10000),
          ],
        ),
        restaurantId: 10,
      );

      final active = profile.activeHeadChef()!;
      expect(
        profile.transferStaff(staff: active, targetRestaurantId: 20),
        isTrue,
      );

      // Quelle: der formelle Chef rückt nach.
      final successor = profile.activeHeadChef();
      expect(successor, isNotNull);
      expect(successor!.id, 2);

      // Ziel: der transferierte Chef ist **formell**.
      final saved = profile.toProfileData();
      final transferred =
          saved.restaurants.firstWhere((r) => r.id == 20).staff.single;
      expect(transferred.headChefRole, kHeadChefRoleFormal);
      expect(transferred.assignedRestaurantId, isNull);
    });
  });
}
