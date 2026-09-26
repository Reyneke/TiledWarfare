import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/management_feature.dart';
import 'package:tiled_warfare/models/management_role.dart';
import 'package:tiled_warfare/models/personality.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/models/staff_entry.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/game_clock_service.dart';
import 'package:tiled_warfare/services/management_feature_service.dart';
import 'package:tiled_warfare/services/rival_service.dart';
import 'package:tiled_warfare/services/staff_role_service.dart';

/// Tests der V12-Erweiterung: vier neue Verwaltungsrollen (Oberkellner,
/// Personalchef, Lagerist, Gewerkschaftschef), ihre passiven Effekte und die
/// aktiven Sonderfertigkeiten „Rush Hour“, „Organisation ist alles“,
/// „Lagertetris“ und „Alle Räder …“.
void main() {
  final start = DateTime(2026, 1, 1);

  StaffEntryData management(
    ManagementRole role, {
    int id = 1,
    String? activeFeature,
    DateTime? activatedAt,
    int? targetId,
    List<int>? teamIds,
  }) => StaffEntryData(
    id: id,
    name: role.name,
    kind: RoleKind.management,
    role: role.name,
    costPerWeek: EconomyBalance.managementRoleWagePerWeek[role] ?? 0,
    activeFeature: activeFeature,
    featureTargetId: targetId,
    featureActivatedAt: activatedAt,
    featureTeamIds: teamIds,
  );

  StaffData staff(
    int id, {
    String rank = kRankApprentice,
    int personalityId = 2,
    int? vitality = 50,
    int? morale = 50,
    int level = 3,
  }) => StaffData(
    name: 'M$id',
    imagePath: 'x.png',
    type: rank,
    rank: rank,
    id: id,
    personalityId: personalityId,
    levelValue: level,
    vitalityCurrent: vitality,
    moraleCurrent: morale,
  );

  RestaurantData restaurant({
    List<StaffEntryData> entries = const [],
    List<StaffData>? staffList,
    int budget = 10000,
  }) => RestaurantData(
    id: 1,
    name: 'R',
    district: 'Midtown',
    budget: budget,
    lastSeenAt: start,
    weekAnchorAt: start,
    staffEntries: entries,
    staff: staffList ?? [staff(11)],
  );

  group('V12-Rollen: Löhne & Feature-Zuordnung', () {
    test('jede V12-Rolle hat Lohn und Feature', () {
      expect(
        managementFeatureOf(ManagementRole.headWaiter),
        ManagementFeature.rushHour,
      );
      expect(
        managementFeatureOf(ManagementRole.personnelManager),
        ManagementFeature.organisationIsEverything,
      );
      expect(
        managementFeatureOf(ManagementRole.storekeeper),
        ManagementFeature.storageTetris,
      );
      expect(
        managementFeatureOf(ManagementRole.unionChief),
        ManagementFeature.unionWorkers,
      );
      for (final role in kAllManagementRoles) {
        expect(
          EconomyBalance.managementRoleWagePerWeek[role],
          isNotNull,
          reason: 'Fehlender Wochenlohn für $role',
        );
      }
      expect(
        EconomyBalance.managementRoleWagePerWeek[ManagementRole.headWaiter],
        150,
      );
      expect(
        EconomyBalance.managementRoleWagePerWeek[ManagementRole.unionChief],
        250,
      );
    });

    test('die V12-Rollen wirken nicht auf das Einkommen', () {
      for (final role in [
        ManagementRole.headWaiter,
        ManagementRole.personnelManager,
        ManagementRole.storekeeper,
        ManagementRole.unionChief,
      ]) {
        expect(StaffRoleService.managementIncomePercent([management(role)]), 0);
      }
    });
  });

  group('V12-Rollen: passive Effekte', () {
    test('Kapazitäts-Bonus stapelt sich additiv', () {
      expect(StaffRoleService.capacityPercent(const []), 0);
      expect(
        StaffRoleService.capacityPercent([
          management(ManagementRole.storekeeper),
        ]),
        EconomyBalance.storekeeperCapacityPercent,
      );
      expect(
        StaffRoleService.capacityPercent([
          management(ManagementRole.headWaiter),
          management(ManagementRole.personnelManager, id: 2),
          management(ManagementRole.storekeeper, id: 3),
        ]),
        EconomyBalance.headWaiterCapacityPercent +
            EconomyBalance.personnelManagerCapacityPercent +
            EconomyBalance.storekeeperCapacityPercent,
      );
    });

    test('Attraktivität/Zufriedenheit heben sich absolut', () {
      expect(StaffRoleService.headWaiterAttractivenessBonus(const []), 0.0);
      expect(
        StaffRoleService.headWaiterAttractivenessBonus([
          management(ManagementRole.headWaiter),
        ]),
        EconomyBalance.headWaiterAttractivenessBonus,
      );
      expect(
        StaffRoleService.personnelManagerSatisfactionBonus([
          management(ManagementRole.personnelManager),
        ]),
        EconomyBalance.personnelManagerSatisfactionBonus,
      );
    });

    test('Kapazität steigt durch den Lageristen', () {
      final plain = restaurant();
      final boosted = restaurant(
        entries: [management(ManagementRole.storekeeper)],
      );
      final base = GameClockService.capacityOf(plain);
      final withStorekeeper = GameClockService.capacityOf(boosted);
      expect(
        (withStorekeeper / base * 100).round(),
        100 + EconomyBalance.storekeeperCapacityPercent,
      );
    });

    test('Gewerkschaftschef: Lohn-Erhöhung und Sink-Senkung', () {
      expect(StaffRoleService.unionChiefWageIncreasePercent(const []), 0);
      expect(
        StaffRoleService.unionChiefWageIncreasePercent([
          management(ManagementRole.unionChief),
        ]),
        EconomyBalance.unionChiefWageIncreasePercent,
      );
      // id 3 ⇒ Kompetenz 4 ⇒ 4 × 6 % = 24 %.
      final chief = management(ManagementRole.unionChief, id: 3);
      expect(ManagementFeatureService.competenceOf(chief), 4);
      expect(
        StaffRoleService.unionChiefSinkReductionPercent([chief]),
        4 * EconomyBalance.unionChiefSinkReductionPercentPerCompetence,
      );
    });

    test('Gewerkschaftschef erhöht die Löhne des Kampfpersonals im Tick', () {
      final plain = restaurant();
      final plainResult = GameClockService.catchUp(
        plain,
        start.add(const Duration(days: 7)),
      );
      final brigade = plainResult.staffCosts;

      final unionized = restaurant(
        entries: [management(ManagementRole.unionChief)],
      );
      final unionizedResult = GameClockService.catchUp(
        unionized,
        start.add(const Duration(days: 7)),
      );

      expect(
        unionizedResult.staffCosts,
        (brigade * (100 + EconomyBalance.unionChiefWageIncreasePercent) / 100)
                .round() +
            EconomyBalance.managementRoleWagePerWeek[ManagementRole
                .unionChief]!,
      );
    });
  });

  group('Rush Hour (V12)', () {
    test('Fenster skaliert mit der Kompetenz', () {
      final owner = management(
        ManagementRole.headWaiter,
        id: 1, // Kompetenz 2
        activeFeature: ManagementFeature.rushHour.name,
        activatedAt: start,
      );
      expect(ManagementFeatureService.competenceOf(owner), 2);
      expect(
        ManagementFeatureService.activeDurationOf(owner),
        EconomyBalance.rushHourPerCompetence * 2,
      );
      expect(
        ManagementFeatureService.aftermathDurationOf(owner),
        Duration.zero,
      );
      expect(
        ManagementFeatureService.inputBoostPercent([owner], start),
        EconomyBalance.rushHourInputBonusPercent,
      );
      expect(
        ManagementFeatureService.inputBoostPercent([
          owner,
        ], start.add(EconomyBalance.rushHourPerCompetence * 3)),
        0,
      );
    });

    test('hebt die Eingangswerte und lässt die Mali entfallen', () {
      final entries = [
        management(
          ManagementRole.headWaiter,
          activeFeature: ManagementFeature.rushHour.name,
          activatedAt: start,
        ),
      ];
      final active = restaurant(entries: entries);
      final plain = restaurant();

      final at = start.add(EconomyBalance.dailyTick);
      expect(
        GameClockService.capacityOf(active, now: at),
        closeTo(
          GameClockService.capacityOf(plain) *
              (1 + EconomyBalance.headWaiterCapacityPercent / 100) *
              1.25,
          1e-9,
        ),
      );
      // Attraktivität/Zufriedenheit werden nur bis zur Eingangs-Domäne
      // geclampt – der Vergleich berücksichtigt das.
      expect(
        GameClockService.attractivenessOf(active, now: at),
        closeTo(
          (GameClockService.attractivenessOf(plain) * 1.25).clamp(
            0.0,
            EconomyBalance.inputDomainMax,
          ),
          1e-9,
        ),
      );
      expect(
        GameClockService.satisfactionOf(active, now: at),
        closeTo(
          (GameClockService.satisfactionOf(plain) * 1.25).clamp(
            0.0,
            EconomyBalance.inputDomainMax,
          ),
          1e-9,
        ),
      );
      expect(ManagementFeatureService.sinkReliefPercent(entries, at), 100);
    });

    test('verteilt die Zusatz-Erschöpfung ranggewichtet', () {
      final entries = [
        management(
          ManagementRole.headWaiter,
          id: 1, // Kompetenz 2 ⇒ Gesamtlast 2 × 2 = 4
          activeFeature: ManagementFeature.rushHour.name,
          activatedAt: start,
        ),
      ];
      final r = restaurant(
        entries: entries,
        staffList: [
          staff(11),
          staff(22, rank: kRankHeadChef),
        ],
      );

      GameClockService.catchUp(r, start.add(EconomyBalance.dailyTick));

      final apprentice = r.staff.firstWhere((s) => s.id == 11);
      final headChef = r.staff.firstWhere((s) => s.id == 22);
      // Der Mali entfällt vollständig ⇒ der Lehrling sinkt nicht …
      expect(apprentice.vitalityCurrent, 50);
      // … der ranghöhere Chef trägt die gesamte Zusatzlast der „Rush Hour“.
      expect(headChef.vitalityCurrent, 46);
      expect(headChef.moraleCurrent, 46);
    });
  });

  group('Lagertetris (V12)', () {
    test('Kapazitäts-Faktor und Kosten skalieren mit der Kompetenz', () {
      final owner = management(
        ManagementRole.storekeeper,
        id: 3, // Kompetenz 4
        activeFeature: ManagementFeature.storageTetris.name,
        activatedAt: start,
      );
      expect(ManagementFeatureService.competenceOf(owner), 4);
      expect(
        ManagementFeatureService.capacityFactor([owner], start),
        1.0 + 4 * EconomyBalance.storageTetrisCapacityFactorPerCompetence,
      );
      expect(
        ManagementFeatureService.activationCostFor(
          ManagementFeature.storageTetris,
          owner,
        ),
        4 * EconomyBalance.storageTetrisCostPerCompetence,
      );
      expect(ManagementFeatureService.sinkReliefPercent([owner], start), 100);
      expect(
        ManagementFeatureService.capacityFactor([
          owner,
        ], start.add(EconomyBalance.storageTetrisActiveDuration)),
        1.0 + 4 * EconomyBalance.storageTetrisCapacityFactorPerCompetence,
      );
      expect(
        ManagementFeatureService.capacityFactor(
          [owner],
          start.add(
            EconomyBalance.storageTetrisActiveDuration +
                EconomyBalance.dailyTick,
          ),
        ),
        1.0,
      );
    });

    test('vervielfacht die Kapazität im Restaurant', () {
      final owner = management(
        ManagementRole.storekeeper,
        id: 1, // Kompetenz 2 ⇒ Faktor 2.0
        activeFeature: ManagementFeature.storageTetris.name,
        activatedAt: start,
      );
      final active = restaurant(entries: [owner]);
      final plain = restaurant();
      expect(
        GameClockService.capacityOf(active, now: start),
        closeTo(
          GameClockService.capacityOf(plain) *
              (1 + EconomyBalance.storekeeperCapacityPercent / 100) *
              2.0,
          1e-9,
        ),
      );
    });
  });

  group('Organisation ist alles (V12)', () {
    test('reduziert den Sink und kostet je aktivem Tag', () {
      final owner = management(
        ManagementRole.personnelManager,
        id: 4, // Kompetenz 1 ⇒ 2 aktive Tage
        activeFeature: ManagementFeature.organisationIsEverything.name,
        activatedAt: start,
      );
      expect(ManagementFeatureService.competenceOf(owner), 1);
      expect(
        ManagementFeatureService.activeDurationOf(owner),
        EconomyBalance.organisationPerCompetence,
      );
      expect(
        ManagementFeatureService.sinkReliefPercent([owner], start),
        EconomyBalance.organisationSinkReductionPercent,
      );
      expect(
        ManagementFeatureService.featureDailyCosts([owner], start),
        EconomyBalance.organisationCostPerDay,
      );

      final withFeature = restaurant(entries: [owner]);
      final result = GameClockService.catchUp(
        withFeature,
        start.add(const Duration(days: 7)),
      );
      expect(
        result.featureCosts,
        2 * EconomyBalance.organisationCostPerDay,
        reason: 'Kompetenz 1 ⇒ 2 aktive Tage im Block',
      );
      expect(
        result.settlements.single.featureCosts,
        2 * EconomyBalance.organisationCostPerDay,
      );
    });

    test('senkt den Tages-Sink des Personals', () {
      final entries = [
        management(
          ManagementRole.personnelManager,
          activeFeature: ManagementFeature.organisationIsEverything.name,
          activatedAt: start,
        ),
      ];
      final withFeature = restaurant(entries: entries);
      final plain = restaurant();
      final at = start.add(EconomyBalance.dailyTick * 2);

      GameClockService.catchUp(withFeature, at);
      GameClockService.catchUp(plain, at);

      expect(
        withFeature.staff.single.vitalityCurrent!,
        greaterThan(plain.staff.single.vitalityCurrent!),
      );
    });
  });

  group('Alle Räder … (V12)', () {
    test('Mannschaft, Rerolls und Shadiness-Bonus', () {
      final chief = management(
        ManagementRole.unionChief,
        id: 3, // Kompetenz 4
        activeFeature: ManagementFeature.unionWorkers.name,
        activatedAt: start,
        teamIds: const [11, 22, 33],
      );
      final entries = [chief];
      final at = start.add(EconomyBalance.dailyTick);
      expect(ManagementFeatureService.sabotageTeamSize(entries, at), 4);
      expect(ManagementFeatureService.sabotageAttempts(entries, at), 4);
      expect(ManagementFeatureService.unionWorkersTeamIds(entries, at), const [
        11,
        22,
        33,
      ]);

      // Gemittelte Shadiness: 50 ⇒ kein Bonus, 100 ⇒ Maximalbonus.
      expect(
        ManagementFeatureService.shadinessBonusPercent(
          const [11, 22],
          const {11: 100, 22: 0},
        ),
        0,
      );
      expect(
        ManagementFeatureService.shadinessBonusPercent(
          const [11],
          const {11: 100},
        ),
        EconomyBalance.shadinessMaxBonusPercent,
      );
      expect(
        ManagementFeatureService.shadinessBonusPercent(
          const [11],
          const {11: 0},
        ),
        -EconomyBalance.shadinessMaxBonusPercent,
      );
      expect(
        ManagementFeatureService.shadinessBonusPercent(const [], const {}),
        0,
      );

      // Reroll je Mitglied: `chancePercent: 100` trifft immer, `0` nie.
      final secretary = management(
        ManagementRole.chefSecretary,
        activeFeature: ManagementFeature.sabotage.name,
        activatedAt: start,
      );
      expect(
        ManagementFeatureService.sabotageSucceeds(
          secretary,
          7,
          attempts: 4,
          chancePercent: 100,
        ),
        isTrue,
      );
      expect(
        ManagementFeatureService.sabotageSucceeds(
          secretary,
          7,
          attempts: 4,
          chancePercent: 0,
        ),
        isFalse,
      );
    });

    test('Erschöpfung trifft die Mannschaft, Shadiness hebt die Chance', () {
      final rival = RivalService.rosterOf('Midtown').first;
      final secretary = management(
        ManagementRole.chefSecretary,
        id: 1,
        activeFeature: ManagementFeature.sabotage.name,
        activatedAt: start,
        targetId: rival.id,
      );
      final chief = management(
        ManagementRole.unionChief,
        id: 3,
        activeFeature: ManagementFeature.unionWorkers.name,
        // Fenster muss die Auflösung (nach 1 Woche) noch abdecken.
        activatedAt: start.add(EconomyBalance.dailyTick),
        teamIds: const [11, 22],
      );
      final r = restaurant(
        entries: [secretary, chief],
        staffList: [staff(11), staff(22)],
      );

      final now = start.add(const Duration(days: 8));
      final expectedShadiness = <int, int>{
        11: PersonalityTraits.forProfile(2, 11).shadiness,
        22: PersonalityTraits.forProfile(2, 22).shadiness,
      };
      expect(
        RivalService.sabotageChancePercent(r, secretary, now),
        ManagementFeatureService.sabotageSuccessPercentFor(secretary) +
            ManagementFeatureService.shadinessBonusPercent(const [
              11,
              22,
            ], expectedShadiness),
      );

      RivalService.resolveSabotage(r, secretary, now);

      final perMember = ManagementFeatureService.sabotageExhaustionPerMember(3);
      for (final s in r.staff) {
        expect(s.vitalityCurrent, 50 - perMember);
        expect(s.moraleCurrent, 50 - perMember);
      }
    });

    test('Mannschaft wird persistiert (Schema v9)', () {
      final entry = management(
        ManagementRole.unionChief,
        activeFeature: ManagementFeature.unionWorkers.name,
        activatedAt: start,
        teamIds: const [7, 8],
      );
      final restored = StaffEntryData.fromJson(entry.toJson());
      expect(restored.featureTeamIds, const [7, 8]);

      final legacy = StaffEntryData.fromJson({'name': 'Alt'});
      expect(legacy.featureTeamIds, isNull);
      expect(kProfileSchemaVersion, 9);
    });
  });

  group('Aktivierung am ObjectProfile (V12)', () {
    void load({
      List<StaffData> staffList = const [],
      List<StaffEntryData> entries = const [],
      int budget = 10000,
    }) {
      ObjectProfile().loadFromData(
        ProfileData(
          id: 1,
          name: 'P',
          creationDate: start,
          restaurants: [
            RestaurantData(
              id: 1,
              name: 'R',
              district: 'Midtown',
              budget: budget,
              lastSeenAt: start,
              weekAnchorAt: start,
              staff: staffList,
              staffEntries: entries,
            ),
          ],
        ),
        restaurantId: 1,
      );
    }

    test('Rush Hour kostet 800 €, Organisation ist alles nichts', () {
      load(
        staffList: [staff(11)],
        entries: [
          management(ManagementRole.headWaiter),
          management(ManagementRole.personnelManager, id: 2),
        ],
      );
      final profile = ObjectProfile();
      expect(
        profile.managementFeatureActivationCost(ManagementFeature.rushHour),
        EconomyBalance.rushHourCost,
      );
      expect(
        profile.activateUntargetedFeature(
          ManagementFeature.rushHour,
          now: start,
        ),
        isTrue,
      );
      expect(profile.budget, 10000 - EconomyBalance.rushHourCost);

      expect(
        profile.activateUntargetedFeature(
          ManagementFeature.organisationIsEverything,
          now: start,
        ),
        isTrue,
      );
      expect(profile.budget, 10000 - EconomyBalance.rushHourCost);
      expect(
        profile.managementFeatureActivationCost(
          ManagementFeature.organisationIsEverything,
        ),
        0,
      );
      expect(
        profile.managementFeatureHasDailyCosts(
          ManagementFeature.organisationIsEverything,
        ),
        isTrue,
      );
    });

    test('Lagertetris kostet Kompetenz × 500 € und sperrt fremde Wege', () {
      load(
        staffList: [staff(11)],
        entries: [management(ManagementRole.storekeeper, id: 3)],
      );
      final profile = ObjectProfile();
      expect(
        profile.managementFeatureActivationCost(
          ManagementFeature.storageTetris,
        ),
        4 * EconomyBalance.storageTetrisCostPerCompetence,
      );
      expect(
        profile.activateUntargetedFeature(
          ManagementFeature.storageTetris,
          now: start,
        ),
        isTrue,
      );
      expect(
        profile.budget,
        10000 - 4 * EconomyBalance.storageTetrisCostPerCompetence,
      );
      // Ziel-/mannschaftsgebundene Features bleiben auf ihrem eigenen Weg.
      expect(
        profile.activateUntargetedFeature(ManagementFeature.sabotage),
        isFalse,
      );
      expect(
        profile.activateUntargetedFeature(ManagementFeature.unionWorkers),
        isFalse,
      );
    });

    test('Alle Räder … begrenzt die Mannschaft auf die Kompetenz', () {
      load(
        staffList: [staff(11), staff(22), staff(33)],
        entries: [management(ManagementRole.unionChief, id: 3)],
      );
      final profile = ObjectProfile();
      expect(profile.unionWorkersTeamLimit, 4);
      final team = profile.personal.take(3).toList();
      final before = profile.budget;
      expect(profile.activateUnionWorkers(team, now: start), isTrue);
      expect(before - profile.budget, EconomyBalance.unionWorkersCost);
      final owner = profile.managementFeatureOwner(
        ManagementFeature.unionWorkers,
      );
      expect(owner?.featureTeamIds, hasLength(3));
      // Zweite Aktivierung ist blockiert (ein Feature je Träger).
      expect(profile.activateUnionWorkers(team, now: start), isFalse);
    });

    test('ohne Träger ist keine Aktivierung möglich', () {
      load(staffList: [staff(11)]);
      final profile = ObjectProfile();
      expect(
        profile.activateUntargetedFeature(ManagementFeature.rushHour),
        isFalse,
      );
      expect(profile.activateUnionWorkers(profile.personal.toList()), isFalse);
      expect(profile.unionWorkersTeamLimit, 0);
    });
  });
}
