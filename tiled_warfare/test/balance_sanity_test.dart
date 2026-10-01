import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/management_feature.dart';
import 'package:tiled_warfare/models/management_role.dart';
import 'package:tiled_warfare/models/match_record.dart';
import 'package:tiled_warfare/models/medic_quality.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/models/restaurant_upgrade.dart';
import 'package:tiled_warfare/models/rival_restaurant.dart';
import 'package:tiled_warfare/models/stations.dart';
import 'package:tiled_warfare/models/support_role.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/economy_service.dart';
import 'package:tiled_warfare/services/game_clock_service.dart';
import 'package:tiled_warfare/services/passive_income_service.dart';
import 'package:tiled_warfare/services/power_projection_service.dart';
import 'package:tiled_warfare/services/rival_service.dart';
import 'package:tiled_warfare/services/management_feature_service.dart';

/// Balance-Sanity-Tests (V7): schreiben die gewünschten Eigenschaften der
/// Wirtschaftsschleife fest, damit Tuning-Änderungen sie nicht unbemerkt
/// brechen.
void main() {
  group('Balance-Tuning: Konfiguration ist konsistent', () {
    test('Fuzzy-Peaks sind geordnet und innerhalb der Domänen', () {
      expect(
        EconomyBalance.fuzzyInputLowPeak,
        lessThan(EconomyBalance.fuzzyInputMidPeak),
      );
      expect(
        EconomyBalance.fuzzyInputMidPeak,
        lessThan(EconomyBalance.fuzzyInputHighPeak),
      );
      expect(
        EconomyBalance.fuzzyInputHighPeak,
        lessThanOrEqualTo(EconomyBalance.inputDomainMax),
      );

      expect(
        EconomyBalance.fuzzyCapacityLowPeak,
        lessThan(EconomyBalance.fuzzyCapacityMidPeak),
      );
      expect(
        EconomyBalance.fuzzyCapacityMidPeak,
        lessThan(EconomyBalance.fuzzyCapacityHighPeak),
      );
      expect(
        EconomyBalance.fuzzyCapacityHighPeak,
        lessThanOrEqualTo(EconomyBalance.capacityMax),
      );

      expect(EconomyBalance.fuzzyFewRepresentative, greaterThan(0));
      expect(
        EconomyBalance.fuzzyFewRepresentative,
        lessThan(EconomyBalance.fuzzyCustomersMidPeak),
      );
      expect(
        EconomyBalance.fuzzyCustomersMidPeak,
        lessThan(EconomyBalance.customersDomainMax),
      );
    });

    test('Budget-/Zins-Invarianten', () {
      expect(EconomyBalance.startBudget, greaterThan(0));
      expect(EconomyBalance.negativeLimit, lessThan(0));
      expect(EconomyBalance.negativeInterestRate, greaterThan(0));
      expect(EconomyBalance.medicBaseCostPerWeek, greaterThan(0));
    });

    test('Heilungs-Balance (V3) ist konsistent', () {
      expect(EconomyBalance.maxWoundValue, greaterThan(0));
      expect(EconomyBalance.healBasePerStage, greaterThan(Duration.zero));
      expect(EconomyBalance.emergencyShotDuration, greaterThan(Duration.zero));
      expect(EconomyBalance.emergencyShotCost, greaterThanOrEqualTo(0));
    });

    test('Tagesschritt passt exakt in den Wochentick (§ 6)', () {
      expect(EconomyBalance.dailyTick, const Duration(days: 1));
      expect(
        EconomyBalance.dailyTick * 7,
        EconomyBalance.weeklyTick,
        reason: '7 Tagesschritte müssen eine Woche ergeben',
      );
      expect(GameClockService.day, EconomyBalance.dailyTick);
      expect(GameClockService.week, EconomyBalance.weeklyTick);
    });

    test(
      'jede Erweiterung hat eine positive Spec mit mindestens einer Stufe',
      () {
        for (final type in UpgradeType.values) {
          final spec = EconomyBalance.upgrades[type];
          expect(spec, isNotNull, reason: 'Fehlende Spec für $type');
          expect(spec!.maxLevel, greaterThanOrEqualTo(1));
          expect(spec.buyBaseCost, greaterThan(0));
          expect(spec.upkeepBaseCostPerWeek, greaterThan(0));
          // Alle Boni sind Zuschläge – nie negativ, nie entwertend.
          for (final percent in [
            spec.capacityBonusPerLevel,
            spec.attractivenessBonusPerLevel,
            spec.satisfactionBonusPerLevel,
            spec.healTimeReductionPerLevel,
            spec.refillBonusPerLevel,
            spec.dailySinkReliefPerLevel,
          ]) {
            expect(
              percent,
              inInclusiveRange(0.0, 1.0),
              reason: 'Unsinniger Bonus in $type',
            );
          }
        }
      },
    );

    test('Ruheraum (V1-Paket) ist der einzige Personal-Ressourcen-Baustein', () {
      final spec = EconomyBalance.upgrades[UpgradeType.lounge]!;
      expect(spec.maxLevel, 3);
      expect(spec.buyBaseCost, 180);
      expect(spec.upkeepBaseCostPerWeek, 18);
      // Entschiedene Wirkungs-Option: beide Effekte, je 3 % pro Stufe.
      expect(spec.refillBonusPerLevel, 0.03);
      expect(spec.dailySinkReliefPerLevel, 0.03);
      // Kein Beitrag zu den drei Eingangswerten oder zur Heilzeit (§ 8).
      expect(spec.capacityBonusPerLevel, 0.0);
      expect(spec.attractivenessBonusPerLevel, 0.0);
      expect(spec.satisfactionBonusPerLevel, 0.0);
      expect(spec.healTimeReductionPerLevel, 0.0);
    });
  });

  group('Balance-Tuning: Einkommen & Zufriedenheit', () {
    RestaurantData restaurant({List<StaffData>? staff, MatchResult? result}) =>
        RestaurantData(
          name: 'Balance',
          district: 'Harlem',
          staff: staff ?? [],
          lastMatchResult: result,
        );

    StaffData staff({String status = 'ready', int moneyValue = 100}) =>
        StaffData(
          name: 'Testkoch',
          imagePath: 'assets/images/token/token_cook_basic.png',
          type: 'apprentice',
          status: status,
          moneyValue: moneyValue,
        );

    int passiveIncome(RestaurantData r) =>
        PassiveIncomeService.passiveIncomePerWeek(
          attractiveness: GameClockService.attractivenessOf(r),
          satisfaction: GameClockService.satisfactionOf(r),
          capacity: GameClockService.capacityOf(r),
        );

    test(
      'frisches Restaurant erwirtschaftet passiv Geld, aber weniger als ein Sieg',
      () {
        final fresh = restaurant(staff: [staff()]);
        final income = passiveIncome(fresh);

        expect(income, greaterThan(0));
        expect(income, lessThan(EconomyBalance.battleRewardBaseWin));
      },
    );

    test('gesundes Team sättigt die Zufriedenheit nicht (Ergebnis wirkt)', () {
      final healthy = restaurant(staff: [staff()]);
      final sat = GameClockService.satisfactionOf(healthy);

      expect(sat, greaterThan(EconomyBalance.satisfactionBase));
      expect(sat, lessThan(EconomyBalance.inputDomainMax));

      final won = restaurant(staff: [staff()], result: MatchResult.win);
      final lost = restaurant(staff: [staff()], result: MatchResult.loss);
      expect(
        GameClockService.satisfactionOf(won),
        greaterThan(GameClockService.satisfactionOf(lost)),
      );
    });

    test('gesundes Team ist besser als todkrankes (Teamgesundheit wirkt)', () {
      final healthy = restaurant(staff: [staff()]);
      final sick = restaurant(staff: [staff(status: 'dying')]);

      expect(
        GameClockService.teamHealthOf(healthy),
        greaterThan(GameClockService.teamHealthOf(sick)),
      );
      expect(
        GameClockService.satisfactionOf(healthy),
        greaterThan(GameClockService.satisfactionOf(sick)),
      );
    });

    test(
      'Maximal-Einkommen ist gedeckelt und unter üppigen Gefechtserlösen',
      () {
        final maxIncome = PassiveIncomeService.passiveIncomePerWeek(
          attractiveness: EconomyBalance.inputDomainMax,
          satisfaction: EconomyBalance.inputDomainMax,
          capacity: EconomyBalance.capacityMax,
        );

        expect(
          maxIncome,
          lessThanOrEqualTo(
            EconomyBalance.customersDomainMax *
                EconomyBalance.passiveIncomePerCustomerPerWeek,
          ),
        );

        final richBattle = EconomyService.battleReward(
          playerWon: true,
          enemyMoneyValues: const [1000, 1000, 1000],
        );
        expect(maxIncome, lessThan(richBattle));
      },
    );
  });

  group('V7-Zentralisierung: Invarianten & Profile', () {
    test('negativeLimit ist der doppelte Startwert (§ 2.2)', () {
      expect(EconomyBalance.negativeLimit, -2 * EconomyBalance.startBudget);
    });

    test('XP-Kurve: Sieg > Niederlage, monoton steigend', () {
      expect(EconomyBalance.xpBaseWin, greaterThan(EconomyBalance.xpBaseLoss));
      for (var level = 1; level < 10; level++) {
        expect(
          EconomyService.levelUpThreshold(level + 1),
          greaterThan(EconomyService.levelUpThreshold(level)),
        );
      }
    });

    test('jede MedicQuality hat einen vollständigen Spec (V7/L2)', () {
      for (final quality in MedicQuality.values) {
        final spec = EconomyBalance.medicQualitySpecs[quality];
        expect(spec, isNotNull, reason: 'Fehlender Spec für $quality');
        expect(spec!.costMultiplier, greaterThan(0));
        expect(spec.survivalBonus, greaterThan(0));
        expect(spec.healTimePerStage, greaterThan(Duration.zero));
      }
      expect(
        EconomyBalance.medicQualitySpecs.length,
        MedicQuality.values.length,
      );
    });

    test('W100-Domäne ist 1–100', () {
      expect(EconomyBalance.d100Min, 1);
      expect(EconomyBalance.d100Max, 100);
    });

    test('Einheiten-Profile existieren und Line Cook ist stärker (V7/L6)', () {
      expect(
        EconomyBalance.lineCookStats.money,
        greaterThan(EconomyBalance.apprenticeStats.money),
      );
      expect(
        EconomyBalance.lineCookStats.attack,
        greaterThan(EconomyBalance.apprenticeStats.attack),
      );
      expect(EconomyBalance.doughZombieStats.money, greaterThan(0));
      expect(EconomyBalance.doughDumpsterStats.wound, greaterThan(0));
    });
  });

  group('Karrierepfade (V10): Aufstiegsleiter & Auren sind konsistent', () {
    test('Aufstiegs-Level steigen monoton', () {
      final levels = [
        EconomyService.promotionLevel('line_cook'),
        EconomyService.promotionLevel('chef_de_partie'),
        EconomyService.promotionLevel('sous_chef'),
        EconomyService.promotionLevel('head_chef'),
      ];
      for (var i = 1; i < levels.length; i++) {
        expect(levels[i], greaterThan(levels[i - 1]));
      }
    });

    test('Aufstiegs-Kosten sind positiv und steigen mit dem Rang', () {
      final costs = [
        EconomyService.promotionCost('line_cook'),
        EconomyService.promotionCost('chef_de_partie'),
        EconomyService.promotionCost('sous_chef'),
        EconomyService.promotionCost('head_chef'),
      ];
      for (final cost in costs) {
        expect(cost, greaterThan(0));
      }
      for (var i = 1; i < costs.length; i++) {
        expect(costs[i], greaterThan(costs[i - 1]));
      }
    });

    test('Aura-Radius steigt monoton mit dem Rang', () {
      expect(EconomyService.stationAuraRadius('apprentice'), 0);
      expect(
        EconomyService.stationAuraRadius('chef_de_partie'),
        greaterThan(0),
      );
      expect(
        EconomyService.stationAuraRadius('sous_chef'),
        greaterThan(EconomyService.stationAuraRadius('chef_de_partie')),
      );
      expect(
        EconomyService.stationAuraRadius('head_chef'),
        greaterThan(EconomyService.stationAuraRadius('sous_chef')),
      );
    });

    test('Transferkosten sind positiv und steigen mit dem Level', () {
      expect(EconomyBalance.transferCostBase, greaterThan(0));
      expect(
        EconomyService.transferCost(level: 5),
        greaterThan(EconomyService.transferCost(level: 1)),
      );
    });

    test('Karriere-Kampfprofile steigen in ATK (V10)', () {
      expect(
        EconomyBalance.chefDePartieStats.attack,
        greaterThan(EconomyBalance.lineCookStats.attack),
      );
      expect(
        EconomyBalance.sousChefStats.attack,
        greaterThan(EconomyBalance.chefDePartieStats.attack),
      );
      expect(
        EconomyBalance.headChefFormalStats.attack,
        greaterThan(EconomyBalance.sousChefStats.attack),
      );
    });

    test('canPromote respektiert die Level-Gates', () {
      expect(
        EconomyService.canPromote(rank: 'chef_de_partie', level: 9),
        isFalse,
      );
      expect(
        EconomyService.canPromote(rank: 'chef_de_partie', level: 10),
        isTrue,
      );
    });

    test('Stations-Bonusse sind definiert und gedeckelt (V10 § 6)', () {
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
      // Jede Variante ersetzt eine bekannte Basis-Station.
      for (final variant in kVariantStations) {
        expect(kBaseStations, contains(EconomyService.baseStationOf(variant)));
      }
      expect(EconomyBalance.stationSwitchCost, greaterThan(0));
      expect(EconomyBalance.patissierRefillBonusPercent, greaterThan(0));
    });

    test('Wochenlöhne, Chef-Buff und Support-Rollen sind konsistent (V10)', () {
      // Chef-de-cuisine-Management-Buff (Phase 5).
      expect(EconomyBalance.headChefManagementBuffPercent, greaterThan(0));

      // Wochenlöhne steigen monoton mit dem Rang (Phase 7).
      const ranks = [
        'apprentice',
        'line_cook',
        'chef_de_partie',
        'sous_chef',
        'head_chef',
      ];
      for (var i = 1; i < ranks.length; i++) {
        expect(
          EconomyService.staffWagePerWeek(ranks[i]),
          greaterThan(EconomyService.staffWagePerWeek(ranks[i - 1])),
        );
      }

      // Hilfs-/Service-Rollen (Phase 6): Lohn und Effekt-Deckel.
      for (final role in SupportRole.values) {
        expect(
          EconomyBalance.supportRoleWagePerWeek[role],
          greaterThan(0),
          reason: 'Fehlender Lohn: $role',
        );
      }
      expect(EconomyBalance.aboyeurIncomePercent, lessThan(100));
      expect(
        EconomyBalance.plongeurUpkeepReductionPercent,
        lessThanOrEqualTo(100),
      );
      expect(
        EconomyBalance.tournantExhaustionReliefPercent,
        lessThanOrEqualTo(100),
      );
    });

    test('Feature-Balance (11a) ist konsistent', () {
      // Kosten, Fenster und Nachteile sind gesetzt und plausibel.
      expect(EconomyBalance.featureCostPerLevel, greaterThan(0));
      expect(
        EconomyBalance.featureActiveDuration,
        EconomyBalance.weeklyTick,
        reason: 'Die aktive Phase dauert genau eine Woche',
      );
      expect(
        EconomyBalance.featureAftermathDuration,
        EconomyBalance.weeklyTick,
        reason: 'Die Nachteilphase dauert genau eine Woche',
      );
      expect(
        EconomyBalance.featureCompetenceMin,
        lessThan(EconomyBalance.featureCompetenceMax),
      );
      expect(
        EconomyBalance.featureCompetenceBoostPercentPerStep,
        greaterThan(0),
      );
      expect(EconomyBalance.featureAftermathSinkMultiplier, greaterThan(1));
      expect(
        EconomyBalance.featureAftermathRefillFraction,
        inExclusiveRange(0.0, 1.0),
      );
      // Die Kompetenz-Spanne deckt die Domäne vollständig ab.
      for (
        var competence = EconomyBalance.featureCompetenceMin;
        competence <= EconomyBalance.featureCompetenceMax;
        competence++
      ) {
        expect(
          ManagementFeatureService.boostPercentFor(competence),
          greaterThan(0),
        );
      }
    });

    test('Verwaltungsrollen (11a E12) sind vollständig balanciert', () {
      for (final role in kAllManagementRoles) {
        expect(
          EconomyBalance.managementRoleWagePerWeek[role],
          isNotNull,
          reason: 'Fehlender Wochenlohn für $role',
        );
        expect(EconomyBalance.managementRoleWagePerWeek[role]!, greaterThan(0));
      }
      expect(
        EconomyBalance.chefSecretaryStaffCostReductionPercent,
        inExclusiveRange(0, 100),
      );
      expect(
        EconomyBalance.chefSecretaryUpgradeCostReductionPercent,
        inExclusiveRange(0, 100),
      );
      expect(
        EconomyBalance.lawyerPenaltyReductionPercent,
        inExclusiveRange(0, 100),
      );
      expect(
        EconomyBalance.accountantOngoingCostReductionPercent,
        inExclusiveRange(0, 100),
      );
      // Ein Kompetenz-4-Winkelzug allein erreicht die Negation.
      expect(
        EconomyBalance.featureCompetenceMax *
            EconomyBalance.legalTrickPenaltyReductionPercentPerStep,
        greaterThanOrEqualTo(100),
      );
    });

    test('Features der Verwaltungsrollen (11a E14–E16) sind konsistent', () {
      for (final feature in kAllManagementFeatures) {
        final cost = ManagementFeatureService.fixedCostOf(feature);
        if (cost != null) expect(cost, greaterThan(0));
      }
      // Sabotage: Vorlauf-, Wirkungs- und Nachlauf-Fenster + Strafe.
      expect(EconomyBalance.sabotageActiveDuration, greaterThan(Duration.zero));
      expect(EconomyBalance.sabotageEffectDuration, greaterThan(Duration.zero));
      expect(
        EconomyBalance.sabotageAftermathDuration,
        greaterThan(Duration.zero),
      );
      expect(EconomyBalance.sabotageCost, greaterThan(0));
      expect(EconomyBalance.sabotageCaughtFine, greaterThan(0));
      // Die Erfolgschance bleibt auch mit maximaler Kompetenz ein Wurf.
      expect(
        EconomyBalance.sabotageBaseSuccessPercent +
            EconomyBalance.featureCompetenceMax *
                EconomyBalance.sabotageSuccessPercentPerStep,
        inExclusiveRange(0, 100),
      );
      // Kreative Buchführung: mindestens ein Tagestick Negation.
      expect(
        EconomyBalance.creativeAccountingPerCompetence,
        greaterThanOrEqualTo(EconomyBalance.dailyTick),
      );
      expect(
        EconomyBalance.creativeAccountingAftermathPerCompetence,
        greaterThan(Duration.zero),
      );
    });

    test('Rollen & Features der V12-Erweiterung sind konsistent', () {
      // Jede der vier V12-Rollen hat Lohn und Feature.
      for (final role in [
        ManagementRole.headWaiter,
        ManagementRole.personnelManager,
        ManagementRole.storekeeper,
        ManagementRole.unionChief,
      ]) {
        expect(EconomyBalance.managementRoleWagePerWeek[role], isNotNull);
        expect(EconomyBalance.managementRoleWagePerWeek[role]!, greaterThan(0));
        expect(managementFeatureOf(role), isNotNull);
      }
      // Passive Prozentwerte liegen im offenen Intervall (0, 100).
      expect(
        EconomyBalance.headWaiterCapacityPercent,
        inExclusiveRange(0, 100),
      );
      expect(
        EconomyBalance.personnelManagerCapacityPercent,
        inExclusiveRange(0, 100),
      );
      expect(
        EconomyBalance.storekeeperCapacityPercent,
        inExclusiveRange(0, 100),
      );
      expect(
        EconomyBalance.unionChiefWageIncreasePercent,
        inExclusiveRange(0, 100),
      );
      // Der Kompetenz-4-Gewerkschaftschef senkt den Sink nicht vollständig.
      expect(
        EconomyBalance.featureCompetenceMax *
            EconomyBalance.unionChiefSinkReductionPercentPerCompetence,
        lessThan(100),
      );
      // Feature-Fenster und Kosten.
      expect(EconomyBalance.rushHourCost, greaterThan(0));
      expect(
        EconomyBalance.rushHourInputBonusPercent,
        inExclusiveRange(0, 100),
      );
      expect(EconomyBalance.rushHourPerCompetence, greaterThan(Duration.zero));
      expect(EconomyBalance.rushHourExhaustionPerCompetence, greaterThan(0));
      expect(EconomyBalance.organisationCostPerDay, greaterThan(0));
      expect(
        EconomyBalance.organisationSinkReductionPercent,
        inExclusiveRange(0, 100),
      );
      expect(EconomyBalance.storageTetrisCostPerCompetence, greaterThan(0));
      expect(
        EconomyBalance.storageTetrisCapacityFactorPerCompetence,
        greaterThan(0),
      );
      expect(EconomyBalance.unionWorkersCost, greaterThan(0));
      expect(EconomyBalance.unionWorkersTeamPerCompetence, greaterThan(0));
      expect(EconomyBalance.shadinessMaxBonusPercent, greaterThan(0));
      expect(EconomyBalance.shadinessMaxBonusPercent, lessThan(100));
      expect(EconomyBalance.shadinessNeutral, greaterThan(0));
      expect(EconomyBalance.sabotageExhaustionPerMission, greaterThan(0));
      // Die vier neuen Features sind (mit-)kostentragend oder laufend bezahlt.
      for (final feature in [
        ManagementFeature.rushHour,
        ManagementFeature.unionWorkers,
      ]) {
        expect(ManagementFeatureService.fixedCostOf(feature), isNotNull);
        expect(ManagementFeatureService.fixedCostOf(feature)!, greaterThan(0));
      }
      // Lagertetris skaliert mit der Kompetenz, „Organisation ist alles“ wird
      // je aktivem Tag bezahlt ⇒ beide ohne feste Einmalkosten.
      expect(
        ManagementFeatureService.fixedCostOf(ManagementFeature.storageTetris),
        isNull,
      );
      expect(
        ManagementFeatureService.fixedCostOf(
          ManagementFeature.organisationIsEverything,
        ),
        isNull,
      );
    });

    test('Sicherheitschef & Gegenschlag (V13) sind konsistent', () {
      // Rolle: Lohn und Feature.
      expect(
        EconomyBalance.managementRoleWagePerWeek[ManagementRole.securityChief],
        greaterThan(0),
      );
      expect(
        managementFeatureOf(ManagementRole.securityChief),
        ManagementFeature.counterSabotage,
      );
      // Passive Entdeckung: auch der Kompetenz-4-Chef deckt nicht sicher auf.
      expect(
        EconomyBalance.featureCompetenceMax *
            EconomyBalance.securityChiefDetectionBonusPercentPerCompetence,
        inExclusiveRange(0, 100),
      );
      expect(
        EconomyBalance.incomingDetectionShadinessToPercent,
        inExclusiveRange(0, 100),
      );
      expect(
        EconomyBalance.incomingSabotageChanceBasePercent,
        inExclusiveRange(0, 100),
      );
      // Der Gegenschlag ist billiger als die eigene Sabotage, aber nicht gratis.
      expect(
        ManagementFeatureService.fixedCostOf(ManagementFeature.counterSabotage),
        EconomyBalance.counterSabotageCost,
      );
      expect(EconomyBalance.counterSabotageCost, greaterThan(0));
      expect(
        EconomyBalance.counterSabotageCost,
        lessThan(EconomyBalance.sabotageCost),
      );
      expect(
        EconomyBalance.counterSabotageActiveDuration,
        greaterThan(Duration.zero),
      );
      expect(
        EconomyBalance.counterSabotageAftermathDuration,
        greaterThan(Duration.zero),
      );
      expect(EconomyBalance.counterSabotageTeamPerCompetence, greaterThan(0));
      // Erfolgschance bleibt unter 100 %, die Strafe unter der der Sabotage.
      expect(
        EconomyBalance.sabotageBaseSuccessPercent +
            EconomyBalance.featureCompetenceMax *
                EconomyBalance.counterSabotageLeaderBonusPercentPerCompetence,
        lessThan(100),
      );
      expect(EconomyBalance.counterSabotageFailureFine, greaterThan(0));
      expect(
        EconomyBalance.counterSabotageFailureFine,
        lessThan(EconomyBalance.sabotageCaughtFine),
      );
    });

    test('Rivalen-Anzahl (Kapitel 13) ist geordnet und gedeckelt', () {
      expect(
        EconomyBalance.rivalCountPrestigeS,
        greaterThan(EconomyBalance.rivalCountPrestigeA),
      );
      expect(
        EconomyBalance.rivalCountPrestigeA,
        greaterThan(EconomyBalance.rivalCountPrestigeB),
      );
      expect(
        EconomyBalance.rivalCountPrestigeB,
        greaterThan(EconomyBalance.rivalCountPrestigeC),
      );
      expect(
        EconomyBalance.rivalCountMin,
        lessThan(EconomyBalance.rivalCountMax),
      );
      for (final count in [
        EconomyBalance.rivalCountS,
        EconomyBalance.rivalCountA,
        EconomyBalance.rivalCountB,
        EconomyBalance.rivalCountC,
        EconomyBalance.rivalCountD,
      ]) {
        expect(
          count,
          inInclusiveRange(
            EconomyBalance.rivalCountMin,
            EconomyBalance.rivalCountMax,
          ),
        );
      }
    });
  });

  group('Power Projection & Rivalen (Kapitel 12/13)', () {
    RestaurantData restaurant({List<StaffData>? staff, MatchResult? result}) =>
        RestaurantData(
          name: 'Balance',
          district: 'Harlem',
          staff: staff ?? [],
          lastMatchResult: result,
        );

    StaffData staff({String status = 'ready', int moneyValue = 100}) =>
        StaffData(
          name: 'Testkoch',
          imagePath: 'assets/images/token/token_cook_basic.png',
          type: 'apprentice',
          status: status,
          moneyValue: moneyValue,
        );

    RivalRestaurant rival({required int id, required double prestige}) =>
        RivalRestaurant(
          id: id,
          name: 'Rivale $id',
          district: 'Harlem',
          personalityId: 1,
          basePrestige: prestige,
        );

    test('PP-Peaks, Faktor-Spannen und Stance-Schwellen sind geordnet', () {
      expect(EconomyBalance.powerProjectionDomainMax, 100);
      expect(
        EconomyBalance.powerProjectionLowRepresentative,
        lessThan(EconomyBalance.powerProjectionLowCeiling),
      );
      expect(
        EconomyBalance.powerProjectionLowCeiling,
        lessThanOrEqualTo(EconomyBalance.powerProjectionMidPeak),
      );
      expect(
        EconomyBalance.powerProjectionMidPeak,
        lessThanOrEqualTo(EconomyBalance.powerProjectionHighFloor),
      );
      expect(
        EconomyBalance.powerProjectionHighFloor,
        lessThan(EconomyBalance.powerProjectionHighRepresentative),
      );
      expect(
        EconomyBalance.powerProjectionHighRepresentative,
        lessThan(EconomyBalance.powerProjectionDomainMax),
      );
      expect(EconomyBalance.powerProjectionIncomeFactorMin, lessThan(1.0));
      expect(EconomyBalance.powerProjectionIncomeFactorMax, greaterThan(1.0));
      expect(EconomyBalance.competitionPressureFactorMin, lessThan(1.0));
      expect(EconomyBalance.competitionPressureFactorMax, greaterThan(1.0));
      expect(
        EconomyBalance.stanceAllyGap,
        lessThan(EconomyBalance.stanceNeutralGap),
      );
      expect(
        EconomyBalance.stanceNeutralGap,
        lessThan(EconomyBalance.stanceEnemyGap),
      );
      expect(EconomyBalance.rivalPpMin, lessThan(EconomyBalance.rivalPpMax));
    });

    test('PP wächst mit den Treibern und bleibt in der Domäne', () {
      int pp(double comp, double ratio, double quality) =>
          PowerProjectionService.powerProjection(
            competition: comp,
            ratio: ratio,
            staffQuality: quality,
          );
      // Wenig Konkurrenz + gute Bilanz + starkes Team ⇒ hohe PP.
      final strong = pp(0.0, 1.0, EconomyBalance.inputDomainMax);
      // Harte Konkurrenz + schlechte Bilanz + schwaches Team ⇒ niedrige PP.
      final weak = pp(1.0, 0.0, 0.0);
      expect(strong, greaterThan(weak));
      for (final value in [strong, weak]) {
        expect(
          value,
          inInclusiveRange(0, EconomyBalance.powerProjectionDomainMax),
        );
      }
    });

    test('Bilanz-Eingang ist neutral ohne Gefecht (P6)', () {
      expect(PowerProjectionService.ratioFromResult(MatchResult.win), 1.0);
      expect(PowerProjectionService.ratioFromResult(MatchResult.loss), 0.0);
      expect(
        PowerProjectionService.ratioFromResult(null),
        EconomyBalance.powerProjectionNeutralInput,
      );
      expect(
        PowerProjectionService.ratioFromResult(MatchResult.draw),
        EconomyBalance.powerProjectionNeutralInput,
      );
    });

    test('Einkommensfaktor liegt in der Spanne und steigt mit PP', () {
      final low = PowerProjectionService.incomeFactor(0);
      final high = PowerProjectionService.incomeFactor(
        EconomyBalance.powerProjectionDomainMax,
      );
      for (final value in [low, high]) {
        expect(
          value,
          inInclusiveRange(
            EconomyBalance.powerProjectionIncomeFactorMin - 0.01,
            EconomyBalance.powerProjectionIncomeFactorMax + 0.01,
          ),
        );
      }
      expect(high, greaterThan(low));
    });

    test('Konkurrenzdruck belohnt Rückstand und bremst die Spitze (Q10)', () {
      final leading = PowerProjectionService.competitionPressureFactor(
        playerPp: EconomyBalance.powerProjectionDomainMax,
        rivalAveragePp: 5,
      );
      final trailing = PowerProjectionService.competitionPressureFactor(
        playerPp: 5,
        rivalAveragePp: 95,
      );
      expect(trailing, greaterThan(leading));
      for (final value in [leading, trailing]) {
        expect(
          value,
          inInclusiveRange(
            EconomyBalance.competitionPressureFactorMin - 0.01,
            EconomyBalance.competitionPressureFactorMax + 0.01,
          ),
        );
      }
    });

    test(
      'Rivalen-Mini-PP ist deterministisch, domänentreu und prestige-monoton',
      () {
        final low = RivalService.rivalPowerProjection(
          rival(id: 7, prestige: 0.7),
          playerPp: 50,
        );
        final high = RivalService.rivalPowerProjection(
          rival(id: 7, prestige: 1.6),
          playerPp: 50,
        );
        expect(high, greaterThan(low));
        expect(
          low,
          inInclusiveRange(
            EconomyBalance.rivalPpMin,
            EconomyBalance.rivalPpMax,
          ),
        );
        // Gleiche Eingaben ⇒ gleiches Ergebnis (idempotent, V8).
        expect(
          RivalService.rivalPowerProjection(
            rival(id: 7, prestige: 0.7),
            playerPp: 50,
          ),
          low,
        );
      },
    );

    test('Stance folgt dem relativen PP-Abstand (Q9)', () {
      expect(
        RivalService.stanceForRival(rivalPp: 50, playerPp: 50),
        RivalStance.ally,
      );
      expect(
        RivalService.stanceForRival(rivalPp: 100, playerPp: 50),
        RivalStance.neutral,
      );
      expect(
        RivalService.stanceForRival(rivalPp: 100, playerPp: 20),
        RivalStance.enemy,
      );
    });

    test('Rangliste ist lückenlos und absteigend sortiert (Kap. 12)', () {
      final r = restaurant(staff: [staff()]);
      final standings = RivalService.standings(r, playerPp: 50);
      final rivalCount = RivalService.rosterOf(r.district).length;
      expect(standings.total, rivalCount + 1);
      expect(standings.playerRank, inInclusiveRange(1, standings.total));
      for (var i = 0; i < standings.entries.length; i++) {
        expect(standings.entries[i].rank, i + 1);
        if (i > 0) {
          expect(
            standings.entries[i].powerProjection,
            lessThanOrEqualTo(standings.entries[i - 1].powerProjection),
          );
        }
      }
    });

    test('Gefechtsteilnahme: 1–4 Rivalen, deterministisch, verteilt (Q8)', () {
      final r = restaurant(staff: [staff()]);
      final rosterIds =
          RivalService.rosterOf(r.district).map((e) => e.id).toSet();
      final count = RivalService.battleParticipantCount(r);
      expect(
        count,
        inInclusiveRange(
          EconomyBalance.rivalBattleMinParticipants,
          EconomyBalance.rivalBattleMaxParticipants,
        ),
      );
      expect(count, lessThanOrEqualTo(rosterIds.length));
      final ids = RivalService.battleParticipantIds(r, playerPp: 50);
      expect(ids.length, count);
      for (final id in ids) {
        expect(rosterIds.contains(id), isTrue);
      }
      expect(RivalService.battleParticipantIds(r, playerPp: 50), ids);
      expect(
        RivalService.distributeBattleSpawns(
          participantCount: 4,
          availableSpawns: 2,
        ),
        [0, 1, 0, 1],
      );
      expect(
        RivalService.distributeBattleSpawns(
          participantCount: 2,
          availableSpawns: 0,
        ),
        isEmpty,
      );
    });

    test('Wochen-Tick liefert PP, Rang, Rivalenzahl und Einkommensfaktor', () {
      final r = restaurant(staff: [staff()]);
      final start = DateTime(2026, 1, 1);
      r.lastSeenAt = start;
      r.weekAnchorAt = start;
      final result = GameClockService.catchUp(
        r,
        start.add(const Duration(days: 7)),
      );
      expect(
        result.powerProjection,
        inInclusiveRange(0, EconomyBalance.powerProjectionDomainMax),
      );
      expect(result.playerRank, greaterThanOrEqualTo(1));
      expect(result.rivalCount, greaterThanOrEqualTo(1));
      expect(result.incomeFactor, greaterThan(0.0));
    });
  });
}
