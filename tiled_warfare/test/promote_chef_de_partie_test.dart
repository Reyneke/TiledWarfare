import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/match_record.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/models/stations.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/objects/player_objects/object_apprentice.dart';
import 'package:tiled_warfare/objects/player_objects/object_chef_de_partie.dart';
import 'package:tiled_warfare/services/economy_balance.dart';

/// Tests der Beförderung `Line Cook → Chef de partie` (Karrierepfade, V10,
/// Phase 3): Level-Gate, Kosten, Identitätserhalt und Persistenz.
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

  StaffData lineCook({
    String name = 'Line Cook: Testkoch',
    String imagePath = 'assets/images/token/token_cook_basic.png',
    int levelValue = 10,
    int woundValue = 3,
    String status = 'ready',
    List<Map<String, dynamic>>? matchHistory,
    int id = -1,
    int personalityId = -1,
  }) =>
      StaffData(
        name: name,
        imagePath: imagePath,
        type: kRankLineCook,
        rank: kRankLineCook,
        levelValue: levelValue,
        woundValue: woundValue,
        status: status,
        matchHistory: matchHistory,
        id: id,
        personalityId: personalityId,
      );

  test('unter Level 10: kein Aufstieg, Budget unverändert', () {
    final profile = ObjectProfile();
    profile.loadFromData(
      profileWith(staff: lineCook(levelValue: 9)),
      restaurantId: 1,
    );

    final budgetBefore = profile.budget;
    final result =
        profile.promoteToRank(profile.personal.single, kRankChefDePartie);

    expect(result, isNull);
    expect(profile.budget, budgetBefore);
    expect(profile.personal.single, isNot(isA<ObjectChefDePartie>()));
  });

  test('ab Level 10: Chef de partie mit bewahrter Identität, Budget −1200', () {
    final profile = ObjectProfile();
    profile.loadFromData(
      profileWith(
        staff: lineCook(
          id: 424242,
          personalityId: 3,
          levelValue: 10,
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
    final promoted = profile.promoteToRank(old, kRankChefDePartie);

    expect(promoted, isA<ObjectChefDePartie>());
    expect(promoted!.rank, kRankChefDePartie);
    expect(
      profile.budget,
      budgetBefore - EconomyBalance.upgradeToChefDePartieCost,
    );
    expect(profile.personal, isNot(contains(old)));
    expect(profile.personal, contains(promoted));

    // Identität bewahrt: Name (nur Rang-Präfix), Bild, Match-Historie.
    expect(promoted.name, 'Chef de partie: Testkoch');
    expect(promoted.imagePath, old.imagePath);
    expect(promoted.matchHistory, hasLength(1));
    expect(promoted.matchHistory.single.opponentName, 'Dough Dumpster');

    // Fortschritt, Zustand, Identität, Persönlichkeit und Ressourcen.
    expect(promoted.levelValue, 10);
    expect(promoted.status, CharacterStatus.hurt);
    expect(promoted.woundValue, 2);
    expect(promoted.id, 424242);
    expect(promoted.personalityId, 3);
    expect(promoted.vitalityCurrent, old.vitalityCurrent);
    expect(promoted.moraleCurrent, old.moraleCurrent);

    // Statprofil des Chef de partie (Beförderung, keine Neuwürfelung).
    expect(promoted.attackValue, EconomyBalance.chefDePartieStats.attack);
    expect(promoted.defenseValue, EconomyBalance.chefDePartieStats.defense);
  });

  test('ein Lehrling kann nicht direkt zum Chef de partie aufsteigen', () {
    final profile = ObjectProfile();
    profile.loadFromData(
      profileWith(
        staff: StaffData(
          name: 'Apprentice: Testkoch',
          imagePath: 'x.png',
          type: kRankApprentice,
          levelValue: 20,
        ),
      ),
      restaurantId: 1,
    );

    final budgetBefore = profile.budget;
    expect(
      profile.promoteToRank(profile.personal.single, kRankChefDePartie),
      isNull,
    );
    expect(profile.budget, budgetBefore);
  });

  test('die Kette endet vorerst: kein doppelter Aufstieg', () {
    final profile = ObjectProfile();
    profile.loadFromData(
      profileWith(staff: lineCook(levelValue: 20)),
      restaurantId: 1,
    );
    final promoted =
        profile.promoteToRank(profile.personal.single, kRankChefDePartie)!;
    final budgetAfterFirst = profile.budget;

    expect(profile.promoteToRank(promoted, kRankChefDePartie), isNull);
    expect(profile.budget, budgetAfterFirst);
  });

  test('unter der Negativgrenze: kein Aufstieg', () {
    final profile = ObjectProfile();
    profile.loadFromData(
      profileWith(staff: lineCook(levelValue: 10), budget: -19900),
      restaurantId: 1,
    );

    final budgetBefore = profile.budget;
    expect(
      profile.promoteToRank(profile.personal.single, kRankChefDePartie),
      isNull,
    );
    expect(profile.budget, budgetBefore);
  });

  test('Rang und Station überleben Speichern und Laden (V10)', () {
    final profile = ObjectProfile();
    profile.loadFromData(
      profileWith(staff: lineCook(levelValue: 10, id: 99, personalityId: 2)),
      restaurantId: 1,
    );

    final promoted =
        profile.promoteToRank(profile.personal.single, kRankChefDePartie)!;
    expect(
      profile.assignStation(promoted, kStationSaucier),
      isTrue,
      reason: 'Die erste Stationswahl ist kostenfrei',
    );

    final saved = profile.toProfileData();
    final savedStaff =
        saved.restaurants.firstWhere((r) => r.id == 1).staff.single;
    expect(savedStaff.rank, kRankChefDePartie);
    expect(savedStaff.type, kRankChefDePartie);
    expect(savedStaff.station, kStationSaucier);

    // Erneut laden: Klasse, Rang und Station bleiben erhalten.
    profile.loadFromData(saved, restaurantId: 1);
    final reloaded = profile.personal.single;
    expect(reloaded, isA<ObjectChefDePartie>());
    expect(reloaded.rank, kRankChefDePartie);
    expect(reloaded.station, kStationSaucier);
    expect(reloaded.id, 99);
  });
}
