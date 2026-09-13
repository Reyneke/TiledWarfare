import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/match_record.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/objects/player_objects/object_apprentice.dart';
import 'package:tiled_warfare/objects/player_objects/object_line_cook.dart';
import 'package:tiled_warfare/services/economy_balance.dart';

/// Tests der Fortbildung Lehrling → Line Cook (V5,
/// `doc/todo/feat_better_restaurant_management/5_Halbfertige_Features.md`).
void main() {
  ProfileData profileWith({required StaffData staff, int budget = 10000}) =>
      ProfileData(
        id: 7,
        name: 'Testprofil',
        creationDate: DateTime(2026, 1, 1),
        restaurants: [
          RestaurantData(
            id: 1,
            name: 'Testrestaurant',
            budget: budget,
            staff: [staff],
          ),
        ],
      );

  StaffData apprentice({
    String name = 'Apprentice: Testkoch',
    String imagePath = 'assets/images/token/token_cook_basic.png',
    int levelValue = 5,
    int woundValue = 3,
    String status = 'ready',
    List<Map<String, dynamic>>? matchHistory,
  }) =>
      StaffData(
        name: name,
        imagePath: imagePath,
        type: 'apprentice',
        levelValue: levelValue,
        woundValue: woundValue,
        status: status,
        matchHistory: matchHistory,
      );

  test('unter Level 5: kein Upgrade, Budget unverändert', () {
    final profile = ObjectProfile();
    profile.loadFromData(
      profileWith(staff: apprentice(levelValue: 4)),
      restaurantId: 1,
    );

    final budgetBefore = profile.budget;
    final result = profile.upgradeToLineCook(profile.personal.single);

    expect(result, isNull);
    expect(profile.budget, budgetBefore);
    expect(profile.personal.single, isNot(isA<ObjectLineCook>()));
  });

  test('ab Level 5: Line Cook mit bewahrter Identität, Budget −500', () {
    final profile = ObjectProfile();
    profile.loadFromData(
      profileWith(
        staff: apprentice(
          levelValue: 5,
          woundValue: 2,
          status: 'hurt',
          matchHistory: [
            MatchRecord(
              date: DateTime(2026, 2, 1),
              opponentName: 'Dough Dumpster',
              result: MatchResult.win,
              kills: 2,
            ).toJson(),
          ],
        ),
      ),
      restaurantId: 1,
    );

    final old = profile.personal.single;
    final budgetBefore = profile.budget;

    final promoted = profile.upgradeToLineCook(old);

    expect(promoted, isA<ObjectLineCook>());
    expect(
      profile.budget,
      budgetBefore - EconomyBalance.upgradeToLineCookCost,
    );
    expect(profile.personal, isNot(contains(old)));
    expect(profile.personal, contains(promoted));

    // Identität bewahrt: Name (nur Rang-Präfix), Bild, Match-Historie.
    expect(promoted!.name, 'Line Cook: Testkoch');
    expect(promoted.imagePath, old.imagePath);
    expect(promoted.matchHistory.length, 1);
    expect(promoted.matchHistory.single.opponentName, 'Dough Dumpster');

    // Fortschritt und Verletzungszustand übernommen.
    expect(promoted.levelValue, 5);
    expect(promoted.status, CharacterStatus.hurt);
    expect(promoted.woundValue, 2);

    // Statprofil des Line Cooks (Beförderung, keine Neuwürfelung).
    expect(promoted.attackValue, 80);
    expect(promoted.defenseValue, 40);
  });

  test('defensiv: Name ohne Lehrlings-Präfix bleibt unverändert', () {
    final profile = ObjectProfile();
    profile.loadFromData(
      profileWith(staff: apprentice(name: 'Mario Rossi', levelValue: 5)),
      restaurantId: 1,
    );

    final promoted = profile.upgradeToLineCook(profile.personal.single);

    expect(promoted!.name, 'Mario Rossi');
  });

  test('unter der Negativgrenze: kein Upgrade', () {
    final profile = ObjectProfile();
    profile.loadFromData(
      profileWith(staff: apprentice(levelValue: 5), budget: -19900),
      restaurantId: 1,
    );

    final budgetBefore = profile.budget;
    final result = profile.upgradeToLineCook(profile.personal.single);

    expect(result, isNull);
    expect(profile.budget, budgetBefore);
  });

  test('ein Line Cook kann nicht erneut fortgebildet werden', () {
    final profile = ObjectProfile();
    profile.loadFromData(
      profileWith(
        staff: StaffData(
          name: 'Line Cook: Testkoch',
          imagePath: 'assets/images/token/token_cook_basic.png',
          type: 'line_cook',
          levelValue: 6,
        ),
      ),
      restaurantId: 1,
    );

    final budgetBefore = profile.budget;
    final result = profile.upgradeToLineCook(profile.personal.single);

    expect(result, isNull);
    expect(profile.budget, budgetBefore);
  });
}
