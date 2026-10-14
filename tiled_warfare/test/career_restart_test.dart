import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/models/stations.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/objects/player_objects/object_apprentice.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/economy_service.dart';

/// Karriere-Neustart auf Level 0 (V10 § 6; P5): die einzige Rückholmöglichkeit
/// eines „aktiv gewesenen“ Charakters – mit Kosten, Zustands-Reset und
/// identitätserhaltender Nachrück-Logik des aktiven Chef de cuisine.
void main() {
  final base = DateTime.utc(2026, 1, 1);

  StaffData staff({
    required int id,
    String rank = kRankSousChef,
    int level = 7,
    String? station = kStationPatissier,
    String? headChefRole,
    String status = 'injured',
  }) => StaffData(
    name: 'Karriere $id',
    imagePath: 'x.png',
    type: 'apprentice',
    rank: rank,
    station: station,
    headChefRole: headChefRole,
    id: id,
    personalityId: 3,
    levelValue: level,
    currentXPValue: 250,
    status: status,
    injuryStartedAt: base,
    injuryStartStatus: 'hurt',
  );

  ProfileData profileWith({
    required List<StaffData> staffList,
    int budget = 20000,
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
        lastSeenAt: base,
        weekAnchorAt: base,
        staff: staffList,
      ),
    ],
  );

  ObjectProfile load({required List<StaffData> staffList, int budget = 20000}) {
    final profile = ObjectProfile();
    profile.loadFromData(
      profileWith(staffList: staffList, budget: budget),
      restaurantId: 10,
    );
    return profile;
  }

  test('Kosten sind level-abhängig und monoton (Muster transferCost)', () {
    expect(
      EconomyService.careerRestartCost(level: 0),
      EconomyBalance.careerRestartCostBase,
    );
    expect(
      EconomyService.careerRestartCost(level: -4),
      EconomyBalance.careerRestartCostBase,
    );
    expect(
      EconomyService.careerRestartCost(level: 7),
      EconomyBalance.careerRestartCostBase +
          7 * EconomyBalance.careerRestartCostPerLevel,
    );
    expect(
      EconomyService.careerRestartCost(level: 8),
      greaterThan(EconomyService.careerRestartCost(level: 7)),
    );
    expect(
      EconomyService.careerRestartCost(level: 7),
      greaterThan(EconomyBalance.upgradeToLineCookCost),
    );
  });

  group('restartCareer', () {
    test('setzt Rang, Level, Station und Zustand zurück und bucht die Kosten',
        () {
      final profile = load(staffList: [staff(id: 4711)]);
      final before = profile.personal.single;
      final cost = EconomyService.careerRestartCost(level: before.levelValue);
      final budgetBefore = profile.budget;

      final restarted = profile.restartCareer(before);

      expect(restarted, isNotNull);
      expect(profile.budget, budgetBefore - cost);
      // Der Zustand enthält nur noch die neue Instanz.
      expect(profile.personal.single, same(restarted));
      expect(profile.personal, hasLength(1));
      // Karriere von vorn.
      expect(restarted!.rank, kRankApprentice);
      expect(restarted.levelValue, 1);
      expect(restarted.currentXPValue, 0);
      expect(restarted.station, isNull);
      expect(restarted.headChefRole, isNull);
      // Zustand geheilt.
      expect(restarted.status, CharacterStatus.ready);
      expect(restarted.injuryStartedAt, isNull);
      expect(restarted.injuryStartStatus, isNull);
      expect(restarted.emergencyShotAt, isNull);
      expect(restarted.suppressedStatus, isNull);
      // Identität bleibt (stabile ID, Persönlichkeit, Grafik).
      expect(restarted.id, before.id);
      expect(restarted.personalityId, before.personalityId);
      expect(restarted.imagePath, before.imagePath);
    });

    test('Lehrlinge können nicht neu starten (Zustand unverändert)', () {
      final profile = load(
        staffList: [
          staff(id: 1, rank: kRankApprentice, level: 3, station: null),
        ],
      );
      final before = profile.personal.single;
      final budgetBefore = profile.budget;

      expect(profile.restartCareer(before), isNull);
      expect(profile.budget, budgetBefore);
      expect(profile.personal.single, same(before));
    });

    test('ohne Budgetdeckung abgelehnt (Zustand unverändert)', () {
      // `canAfford` erlaubt Buchungen bis zur Negativgrenze – erst darunter
      // wird der Neustart abgelehnt.
      final profile = load(
        staffList: [staff(id: 9)],
        budget: EconomyBalance.negativeLimit,
      );
      final before = profile.personal.single;

      expect(profile.restartCareer(before), isNull);
      expect(profile.budget, EconomyBalance.negativeLimit);
      expect(profile.personal.single, same(before));
      expect(before.rank, kRankSousChef);
      expect(before.levelValue, 7);
    });

    test('Charakter außerhalb des Teams wird abgelehnt', () {
      final profile = load(staffList: [staff(id: 1)]);
      final foreign = ObjectApprentice(name: 'Fremd', imagePath: 'x.png');

      expect(profile.restartCareer(foreign), isNull);
      expect(profile.budget, 20000);
    });

    test('aktiver Chef de cuisine: ein formeller Chef rückt nach', () {
      final profile = load(
        staffList: [
          staff(
            id: 1,
            rank: kRankHeadChef,
            level: 9,
            station: null,
            headChefRole: kHeadChefRoleActive,
          ),
          staff(
            id: 2,
            rank: kRankHeadChef,
            level: 5,
            station: null,
            headChefRole: kHeadChefRoleFormal,
          ),
        ],
      );
      final active = profile.activeHeadChef();
      expect(active, isNotNull);
      expect(active!.id, 1);

      final restarted = profile.restartCareer(active);

      expect(restarted, isNotNull);
      expect(profile.activeHeadChef()!.id, 2);
      expect(profile.activeHeadChef()!.headChefRole, kHeadChefRoleActive);
      expect(
        profile.personal.where((c) => c.rank == kRankHeadChef),
        hasLength(1),
      );
    });
  });
}
