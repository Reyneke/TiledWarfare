import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/personality.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/models/support_role.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/economy_service.dart';
import 'package:tiled_warfare/services/game_clock_service.dart';

/// Tests der wöchentlichen Löhne (Karrierepfade, V10, Phase 7).
void main() {
  final start = DateTime(2026, 1, 1);

  StaffData staffData({
    required String rank,
    required int id,
    int personalityId = 2,
    int levelValue = 8,
  }) =>
      StaffData(
        name: 'Koch $id',
        imagePath: 'x.png',
        type: rank,
        rank: rank,
        levelValue: levelValue,
        id: id,
        personalityId: personalityId,
      );

  RestaurantData restaurant({
    required List<StaffData> staff,
    List<SupportRoleData> support = const [],
  }) =>
      RestaurantData(
        id: 1,
        name: 'R',
        budget: 10000,
        district: 'Harlem',
        lastSeenAt: start,
        weekAnchorAt: start,
        staff: staff,
        supportStaff: support,
      );

  test('Wochenlöhne steigen monoton mit dem Rang', () {
    final ranks = [
      kRankApprentice,
      kRankLineCook,
      kRankChefDePartie,
      kRankSousChef,
      kRankHeadChef,
    ];
    final wages =
        ranks.map((r) => EconomyService.staffWagePerWeek(r)).toList();
    for (var i = 1; i < wages.length; i++) {
      expect(wages[i], greaterThan(wages[i - 1]));
    }
    expect(
      EconomyService.staffWagePerWeek('gibtsnicht'),
      EconomyBalance.staffWageFallbackPerWeek,
    );
  });

  test('Thriftiness verschiebt den Wochenlohn (50 = neutral)', () {
    final neutral = EconomyService.staffWagePerWeek(kRankLineCook, 50);
    expect(EconomyService.staffWagePerWeek(kRankLineCook, 100), lessThan(neutral));
    expect(EconomyService.staffWagePerWeek(kRankLineCook, 0), greaterThan(neutral));
  });

  test('billWeeklyStaffWages summiert über Wochen', () {
    expect(EconomyService.billWeeklyStaffWages([100, 200], 2), 600);
    expect(EconomyService.billWeeklyStaffWages([100], 0), 0);
  });

  test('Wochentick bucht die Löhne am Blockende ab und ist idempotent', () {
    final r = restaurant(
      staff: [
        staffData(rank: kRankApprentice, id: 1, personalityId: 2),
        staffData(rank: kRankLineCook, id: 2, personalityId: 3),
      ],
    );
    final budgetBefore = r.budget;

    final result =
        GameClockService.catchUp(r, start.add(const Duration(days: 7)));

    final expected = EconomyService.staffWagePerWeek(
          kRankApprentice,
          PersonalityTraits.forProfile(2, 1).thriftiness,
        ) +
        EconomyService.staffWagePerWeek(
          kRankLineCook,
          PersonalityTraits.forProfile(3, 2).thriftiness,
        );

    expect(result.weeks, 1);
    expect(result.staffCosts, expected);
    expect(result.settlements.single.staffCosts, expected);

    // Budget-Invariante des Wochenticks.
    expect(
      result.budgetAfter,
      budgetBefore +
          result.passiveIncome -
          result.medicCosts -
          result.staffCosts -
          result.upgradeUpkeep -
          result.negativeInterest,
    );

    // Idempotenz: derselbe Zeitpunkt wird nicht erneut abgerechnet.
    final second =
        GameClockService.catchUp(r, start.add(const Duration(days: 7)));
    expect(second.staffCosts, 0);
    expect(second.passiveIncome, 0);
  });

  test('Hilfs-/Service-Rollen werden mitgebucht (V10, Phase 6)', () {
    final r = restaurant(
      staff: [staffData(rank: kRankApprentice, id: 1, personalityId: 2)],
      support: [
        SupportRoleData(
          id: 9,
          name: 'Plongeur',
          role: SupportRole.plongeur.name,
          costPerWeek: 70,
        ),
      ],
    );

    final result =
        GameClockService.catchUp(r, start.add(const Duration(days: 7)));

    final staffWage = EconomyService.staffWagePerWeek(
      kRankApprentice,
      PersonalityTraits.forProfile(2, 1).thriftiness,
    );
    expect(result.staffCosts, staffWage + 70);
  });
}
