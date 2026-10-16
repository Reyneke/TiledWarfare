import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/management_feature.dart';
import 'package:tiled_warfare/models/management_role.dart';
import 'package:tiled_warfare/models/match_record.dart';
import 'package:tiled_warfare/models/medic_quality.dart';
import 'package:tiled_warfare/models/personality.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/models/restaurant_upgrade.dart';
import 'package:tiled_warfare/models/rival_restaurant.dart';
import 'package:tiled_warfare/models/stations.dart';
import 'package:tiled_warfare/models/support_role.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/economy_service.dart';
import 'package:tiled_warfare/services/frt_service.dart';
import 'package:tiled_warfare/services/game_clock_service.dart';
import 'package:tiled_warfare/services/passive_income_service.dart';
import 'package:tiled_warfare/services/power_projection_service.dart';
import 'package:tiled_warfare/services/rival_service.dart';
import 'package:tiled_warfare/services/stress_service.dart';
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
            spec.penaltyReductionPerLevel,
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

    test('Zertifizierung (P3) koppelt die Strafen-Minderung an die Inspektion',
        () {
      final spec = EconomyBalance.upgrades[UpgradeType.certification]!;
      expect(spec.maxLevel, 3);
      expect(spec.buyBaseCost, 200);
      expect(spec.upkeepBaseCostPerWeek, 20);
      // Entschiedene Wirkungs-Option: −5 % Strafen je Stufe, sonst nichts.
      expect(spec.penaltyReductionPerLevel, 0.05);
      expect(spec.capacityBonusPerLevel, 0.0);
      expect(spec.attractivenessBonusPerLevel, 0.0);
      expect(spec.satisfactionBonusPerLevel, 0.0);
      expect(spec.healTimeReductionPerLevel, 0.0);
      expect(spec.refillBonusPerLevel, 0.0);
      expect(spec.dailySinkReliefPerLevel, 0.0);

      // Die zweite Strafenquelle (Behörden-Inspektion) hat sinnvolle Werte.
      expect(EconomyBalance.inspectionIntervalWeeks, greaterThanOrEqualTo(1));
      expect(EconomyBalance.inspectionFineBase, greaterThan(0));
      expect(
        EconomyBalance.inspectionCorruptionSurchargePercent,
        greaterThanOrEqualTo(0),
      );
    });

    test('Tresor (P3) ist der einzige Zins-Satz-Hebel', () {
      final spec = EconomyBalance.upgrades[UpgradeType.vault]!;
      expect(spec.maxLevel, 3);
      expect(spec.buyBaseCost, 200);
      expect(spec.upkeepBaseCostPerWeek, 20);
      // Entschiedene Wirkungs-Option: −10 % des Zins-Satzes je Stufe.
      expect(spec.negativeInterestReliefPerLevel, 0.10);
      expect(spec.capacityBonusPerLevel, 0.0);
      expect(spec.attractivenessBonusPerLevel, 0.0);
      expect(spec.satisfactionBonusPerLevel, 0.0);
      expect(spec.trainingCostReductionPerLevel, 0.0);
      expect(spec.detectionBonusPerLevel, 0.0);
      expect(spec.prestigeBonusPerLevel, 0.0);
      expect(spec.sabotageTargetReliefPerLevel, 0.0);
    });

    test('Schulungsraum (P3) ist der einzige Ausbildungskosten-Hebel', () {
      final spec = EconomyBalance.upgrades[UpgradeType.school]!;
      expect(spec.maxLevel, 3);
      expect(spec.buyBaseCost, 300);
      expect(spec.upkeepBaseCostPerWeek, 30);
      // Entschiedene Wirkungs-Option: −5 % Beförderungskosten je Stufe.
      expect(spec.trainingCostReductionPerLevel, 0.05);
      expect(spec.capacityBonusPerLevel, 0.0);
      expect(spec.attractivenessBonusPerLevel, 0.0);
      expect(spec.satisfactionBonusPerLevel, 0.0);
      expect(spec.negativeInterestReliefPerLevel, 0.0);
      expect(spec.detectionBonusPerLevel, 0.0);
      expect(spec.prestigeBonusPerLevel, 0.0);
      expect(spec.sabotageTargetReliefPerLevel, 0.0);
    });

    test('Sicherheitstechnik (P3) ist der einzige Entdeckungs-Hebel', () {
      final spec = EconomyBalance.upgrades[UpgradeType.security]!;
      expect(spec.maxLevel, 3);
      expect(spec.buyBaseCost, 220);
      expect(spec.upkeepBaseCostPerWeek, 22);
      // Entschiedene Wirkungs-Option: +5 Prozentpunkte Entdeckung je Stufe.
      expect(spec.detectionBonusPerLevel, 0.05);
      expect(spec.capacityBonusPerLevel, 0.0);
      expect(spec.attractivenessBonusPerLevel, 0.0);
      expect(spec.satisfactionBonusPerLevel, 0.0);
      expect(spec.trainingCostReductionPerLevel, 0.0);
      expect(spec.prestigeBonusPerLevel, 0.0);
      expect(spec.sabotageTargetReliefPerLevel, 0.0);
    });

    test('Sterneküche (P3) trägt Prestige und Ziel-Schutz, sonst nichts', () {
      final spec = EconomyBalance.upgrades[UpgradeType.stars]!;
      expect(spec.maxLevel, 5);
      expect(spec.buyBaseCost, 400);
      expect(spec.upkeepBaseCostPerWeek, 40);
      // Entschiedene Wirkungs-Option: beide Effekte („und“).
      expect(spec.prestigeBonusPerLevel, 0.01);
      expect(spec.sabotageTargetReliefPerLevel, 0.05);
      expect(spec.capacityBonusPerLevel, 0.0);
      expect(spec.attractivenessBonusPerLevel, 0.0);
      expect(spec.satisfactionBonusPerLevel, 0.0);
      expect(spec.negativeInterestReliefPerLevel, 0.0);
      expect(spec.trainingCostReductionPerLevel, 0.0);
      expect(spec.detectionBonusPerLevel, 0.0);
    });

    test('FRT-Fehde (C2) und Q7b haben sinnvolle Balance-Werte', () {
      expect(EconomyBalance.frtFeudWeeks, greaterThanOrEqualTo(1));
      expect(
        EconomyBalance.frtRivalAttackSharePercent,
        inInclusiveRange(0, 100),
      );
      expect(EconomyBalance.frtRivalAttackPpLoss, greaterThan(0));
      // Der Angriffs-PP-Verlust darf die Domäne nicht sprengen.
      expect(
        EconomyBalance.frtRivalAttackPpLoss,
        lessThanOrEqualTo(EconomyBalance.rivalPpMax),
      );
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

    test('Effektiver Einkommensfaktor ist das Produkt beider Stufen (Q10)', () {
      const pp = 80;
      const rivalAveragePp = 20.0;
      final expected =
          PowerProjectionService.incomeFactor(pp) *
              PowerProjectionService.competitionPressureFactor(
                playerPp: pp,
                rivalAveragePp: rivalAveragePp,
              );
      final effective = PowerProjectionService.effectiveIncomeFactor(
        playerPp: pp,
        rivalAveragePp: rivalAveragePp,
      );
      expect(effective, closeTo(expected, 1e-9));
      // Beide Spannen multiplizieren sich; das Ergebnis bleibt positiv.
      expect(
        effective,
        inInclusiveRange(
          EconomyBalance.powerProjectionIncomeFactorMin *
              EconomyBalance.competitionPressureFactorMin,
          EconomyBalance.powerProjectionIncomeFactorMax *
              EconomyBalance.competitionPressureFactorMax,
        ),
      );
    });

    test('Konkurrenzdruck ist bei Gleichstand neutral und sonst monoton (Q10)',
        () {
      final leading = PowerProjectionService.competitionPressureFactor(
        playerPp: EconomyBalance.powerProjectionDomainMax,
        rivalAveragePp: 0,
      );
      final level = PowerProjectionService.competitionPressureFactor(
        playerPp: 50,
        rivalAveragePp: 50,
      );
      final trailing = PowerProjectionService.competitionPressureFactor(
        playerPp: 0,
        rivalAveragePp: EconomyBalance.powerProjectionDomainMax.toDouble(),
      );
      // Wer hinten liegt, erhält Aufhol-Bonus; wer führt, Gegenwind.
      expect(leading, lessThan(level));
      expect(level, lessThan(trailing));
      expect(level, closeTo(1.0, 0.05));
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

  group('FRT-Korruption: Balance ist konsistent (Kapitel 14)', () {
    test('alle frt*-Werte sind zentral und nicht-negativ (V7)', () {
      expect(EconomyBalance.frtCorruptionPerWeekPercent, greaterThan(0));
      expect(EconomyBalance.frtCorruptionPerSabotagePercent, greaterThan(0));
      expect(
        EconomyBalance.frtCorruptionPerEliminationPercent,
        greaterThan(0),
      );
      expect(EconomyBalance.frtCorruptionReducePerMonsterPercent, greaterThan(0));
      expect(EconomyBalance.frtCorruptionReducePerVictoryPercent, greaterThan(0));
      expect(EconomyBalance.frtMonsterStrengthScalePercent, greaterThan(0));
      expect(EconomyBalance.frtCorruptionIncomePenaltyMaxPercent, greaterThan(0));
      expect(
        EconomyBalance.frtPowerProjectionPenaltyPercent,
        inInclusiveRange(0, 100),
      );
      // Q6: Anteil der eingehenden Angriffe, die FRT-Fehl-Attributionen sind.
      expect(EconomyBalance.frtSabotageSharePercent, inInclusiveRange(0, 100));
    });

    test('Floor < Ceiling und Verlustschwelle im gültigen Bereich', () {
      expect(
        EconomyBalance.frtCorruptionFloorPercent,
        lessThan(EconomyBalance.frtCorruptionCeilingPercent),
      );
      expect(
        EconomyBalance.frtCorruptionLostThresholdPercent,
        inInclusiveRange(
          EconomyBalance.frtCorruptionFloorPercent,
          EconomyBalance.frtCorruptionCeilingPercent,
        ),
      );
    });

    test('Malus-Prozente bleiben im zulässigen Rahmen', () {
      expect(FrtService.incomeMalusPercent(0), 0);
      expect(
        FrtService.incomeMalusPercent(EconomyBalance.frtCorruptionCeilingPercent),
        closeTo(EconomyBalance.frtCorruptionIncomePenaltyMaxPercent, 1e-9),
      );
      expect(
        FrtService.monsterStrengthFactor(0),
        1.0,
        reason: 'Ohne Korruption darf es keinen Monster-Bonus geben',
      );
      expect(
        FrtService.monsterStrengthFactor(EconomyBalance.frtCorruptionCeilingPercent),
        closeTo(
          1 + EconomyBalance.frtMonsterStrengthScalePercent / 100,
          1e-9,
        ),
      );
    });

    test('Korruption bleibt stets auf 0–100 geklemmt', () {
      final max = EconomyBalance.frtCorruptionCeilingPercent;
      var value = 0.0;
      for (var week = 0; week < 500; week++) {
        value = FrtService.afterBlock(value);
        expect(value, greaterThanOrEqualTo(EconomyBalance.frtCorruptionFloorPercent));
        expect(value, lessThanOrEqualTo(max));
      }
      expect(
        FrtService.reduce(0, monstersKilled: 100, victory: true),
        EconomyBalance.frtCorruptionFloorPercent,
      );
    });
  });

  group('Balance-Tuning: Teamdynamik & Karriere-Neustart (P5)', () {
    test('Affinitäts-Buckets sind geordnet und innerhalb des Modulos', () {
      expect(
        EconomyBalance.teamChemistryPositiveBound,
        lessThan(EconomyBalance.teamChemistryNegativeBound),
      );
      expect(
        EconomyBalance.teamChemistryNegativeBound,
        lessThan(EconomyBalance.teamChemistryBucketModulo),
      );
      expect(EconomyBalance.teamChemistryAttractivenessWeight, greaterThan(0));
      expect(EconomyBalance.teamChemistrySatisfactionWeight, greaterThan(0));
    });

    test('Team-Chemie bleibt ein moderater Eingangs-Anteil', () {
      // Nie stärker als die mehrfache Persönlichkeits-Wirkung – die Chemie
      // ist ein Nudge auf Stimmung/Attraktivität, kein dominanter Hebel.
      expect(
        EconomyBalance.teamChemistryAttractivenessWeight,
        lessThan(EconomyBalance.personalityAttractivenessWeight * 4),
      );
      expect(
        EconomyBalance.teamChemistryAttractivenessWeight,
        lessThan(EconomyBalance.satisfactionHealthWeight * 4),
      );
    });

    test('Karriere-Neustart ist level-abhängig und monoton', () {
      expect(
        EconomyService.careerRestartCost(level: 0),
        EconomyBalance.careerRestartCostBase,
      );
      expect(
        EconomyService.careerRestartCost(level: -3),
        EconomyBalance.careerRestartCostBase,
      );
      expect(
        EconomyService.careerRestartCost(level: 5),
        greaterThan(EconomyService.careerRestartCost(level: 4)),
      );
      // Der Neustart ist nie billiger als die erste Fortbildungsstufe – er
      // vernichtet mindestens so viel Wert, wie der Aufstieg gekostet hat.
      expect(
        EconomyBalance.careerRestartCostBase,
        greaterThanOrEqualTo(EconomyBalance.upgradeToLineCookCost),
      );
    });

    test('Pâtissier-Profil ist Support mit Kapazitäts-Orientierung', () {
      expect(EconomyService.isSupportStation(kStationPatissier), isTrue);
      expect(
        EconomyService.stationAuraPercent(kStationPatissier, StationStat.attack),
        0,
      );
      expect(
        EconomyBalance.patissierStats.attack,
        lessThan(EconomyBalance.chefDePartieStats.attack),
      );
      expect(
        EconomyBalance.patissierStats.money,
        greaterThan(EconomyBalance.chefDePartieStats.money),
      );
    });
  });

  /// P7 (4.2/#10): Der Werte-Pass schreibt die Tuning-Größen fest, die bis
  /// dahin nur „gefühlt“ plausibel waren – Stations-/Aura-Werte, Lohn-Spanne,
  /// `ruheMargin`, Sink-Werte, Trait-Prozente und die Zuordnung
  /// Rolle ↔ Erweiterung (`10`, `11a`, `11b`, `9`).
  group('Balance-Tuning: Werte-Pass (P7, 4.2/#10)', () {
    int maxSelf(String station) {
      var best = 0;
      for (final stat in StationStat.values) {
        final value = EconomyService.stationBonusPercent(station, stat);
        if (value > best) best = value;
      }
      return best;
    }

    /// Gesamt-Profil (Selbstwirkung **und** Aura) einer Station je Stat – die
    /// Vergleichsbasis für die Dominanz-Prüfung.
    List<int> profileOf(String station) => [
          for (final stat in StationStat.values)
            EconomyService.stationBonusPercent(station, stat) +
                EconomyService.stationAuraPercent(station, stat),
        ];

    /// `true`, wenn [a] mindestens so stark ist wie [b] und in mindestens einem
    /// Wert echt stärker – dann wäre [b] als Wahl entwertet.
    bool dominates(List<int> a, List<int> b) {
      var strictlyBetter = false;
      for (var i = 0; i < a.length; i++) {
        if (a[i] < b[i]) return false;
        if (a[i] > b[i]) strictlyBetter = true;
      }
      return strictlyBetter;
    }

    test('keine Station entwertet ihre Basis oder ihre Geschwister (P7)', () {
      for (final variant in kVariantStations) {
        final base = EconomyService.baseStationOf(variant)!;
        expect(
          dominates(profileOf(variant), profileOf(base)),
          isFalse,
          reason: 'Variante $variant dominiert ihre Basis $base',
        );
        expect(
          dominates(profileOf(base), profileOf(variant)),
          isFalse,
          reason: 'Basis $base entwertet Variante $variant',
        );
        for (final sibling in kVariantStations) {
          if (sibling == variant) continue;
          if (EconomyService.baseStationOf(sibling) != base) continue;
          expect(
            dominates(profileOf(sibling), profileOf(variant)),
            isFalse,
            reason: 'Geschwister $sibling und $variant sind nicht unterscheidbar',
          );
        }
      }
    });

    test('Varianten ersetzen den Fokus, sie verstärken ihn nicht (P7)', () {
      for (final variant in kVariantStations) {
        final base = EconomyService.baseStationOf(variant)!;
        expect(
          maxSelf(variant),
          lessThanOrEqualTo(maxSelf(base)),
          reason: 'Variante $variant verstärkt den Fokus ihrer Basis $base',
        );
      }
    });

    test('Auren bleiben schwächer als die eigene Spezialisierung (P7)', () {
      for (final station in kAllStations) {
        final isSupport = EconomyService.isSupportStation(station);
        var maxAura = 0;
        for (final stat in StationStat.values) {
          final aura = EconomyService.stationAuraPercent(station, stat);
          if (aura > maxAura) maxAura = aura;
        }
        if (isSupport) {
          expect(
            maxAura,
            0,
            reason: 'Support-Station $station darf keine Kampf-Aura tragen',
          );
          continue;
        }
        expect(
          maxAura,
          greaterThan(0),
          reason: 'Kampf-Station $station trägt keine Aura',
        );
        expect(
          maxAura,
          lessThanOrEqualTo(maxSelf(station)),
          reason: 'Die Aura von $station ist stärker als ihre Selbstwirkung',
        );
        // Die Reichweite ist bewusst aura-frei (Tuning-Entscheidung, `10` § 2).
        expect(EconomyService.stationAuraPercent(station, StationStat.range), 0);
      }
    });

    test('Lohn-Spanne (Thriftiness) bleibt ein moderater Korridor (P7)', () {
      expect(EconomyBalance.thriftinessWageSpread, greaterThan(0));
      expect(EconomyBalance.thriftinessWageSpread, lessThanOrEqualTo(0.5));

      const ranks = [
        'apprentice',
        'line_cook',
        'chef_de_partie',
        'sous_chef',
        'head_chef',
      ];
      for (final rank in ranks) {
        final neutral = EconomyService.staffWagePerWeek(rank);
        final thrifty = EconomyService.staffWagePerWeek(rank, 100);
        final wasteful = EconomyService.staffWagePerWeek(rank, 0);
        expect(thrifty, lessThan(neutral));
        expect(wasteful, greaterThan(neutral));
        expect(
          wasteful - neutral,
          neutral - thrifty,
          reason: 'Der Korridor muss um den Neutralwert symmetrisch bleiben',
        );
        expect(
          wasteful,
          lessThan(neutral * 2),
          reason: 'Ein verschwenderischer Charakter verdoppelt den Lohn nicht',
        );
        expect(
          thrifty,
          greaterThan(neutral ~/ 2),
          reason: 'Sparen darf Personal nicht fast gratis machen',
        );
      }

      // Derselbe Korridor gilt für den Teamarzt (eine Quelle: Spread).
      final neutralMedic = EconomyService.weeklyMedicCost(
        MedicQuality.niedrig,
        3,
      );
      expect(
        EconomyService.weeklyMedicCost(MedicQuality.niedrig, 3, 100),
        lessThan(neutralMedic),
      );
      expect(
        EconomyService.weeklyMedicCost(MedicQuality.niedrig, 3, 0),
        greaterThan(neutralMedic),
      );
    });

    test('das Aufstiegs-Gate wächst mit dem Rang (P7)', () {
      const ranks = ['line_cook', 'chef_de_partie', 'sous_chef', 'head_chef'];
      final weeksPerWage = [
        for (final rank in ranks)
          EconomyService.promotionCost(rank) /
              EconomyService.staffWagePerWeek(rank),
      ];
      // Ein höherer Rang ist relativ zum Lohn teurer zu erreichen – die
      // Leiter ist ein Gate, kein Selbstläufer.
      for (var i = 1; i < weeksPerWage.length; i++) {
        expect(
          weeksPerWage[i],
          greaterThanOrEqualTo(weeksPerWage[i - 1]),
          reason: '${ranks[i]} ist relativ billiger als ${ranks[i - 1]}',
        );
      }
      expect(
        weeksPerWage.first,
        greaterThan(1),
        reason: 'Schon der erste Aufstieg kostet mehr als eine Woche Lohn',
      );
    });

    test('Rollen-Löhne bleiben im Band und gestaffelt (P7)', () {
      for (final role in SupportRole.values) {
        expect(
          EconomyBalance.supportRoleWagePerWeek[role]!,
          inInclusiveRange(50, 200),
          reason: 'Hilfsrolle $role verlässt den Lohn-Korridor',
        );
      }
      for (final role in kAllManagementRoles) {
        expect(
          EconomyBalance.managementRoleWagePerWeek[role]!,
          inInclusiveRange(100, 300),
          reason: 'Verwaltungsrolle $role verlässt den Lohn-Korridor',
        );
      }
      int maxOf(Iterable<int> values) => values.fold(0, (a, b) => a > b ? a : b);
      expect(
        maxOf(EconomyBalance.supportRoleWagePerWeek.values),
        lessThan(maxOf(EconomyBalance.managementRoleWagePerWeek.values)),
        reason: 'Die Verwaltung ist die teurere Rollen-Kategorie',
      );
    });

    test('Sink-Werte bleiben in der Ressourcen-Domäne (P7)', () {
      expect(EconomyBalance.resourceSinkPerDay, greaterThan(0));
      expect(
        EconomyBalance.resourceSinkPerBattle,
        2 * EconomyBalance.resourceSinkPerDay,
        reason: 'Ein Gefechtseinsatz kostet zwei Ruhetage',
      );
      // Eine Woche ohne Gefecht darf keinen Median-Charakter (50) leerräumen.
      expect(
        7 * EconomyBalance.resourceSinkPerDay,
        lessThanOrEqualTo(EconomyBalance.personalityTraitMax ~/ 2),
      );
      // Auch der doppelte Sink der Feature-Nachteilphase bleibt eine Woche lang
      // innerhalb der Domäne.
      expect(
        7 *
            EconomyBalance.resourceSinkPerDay *
            EconomyBalance.featureAftermathSinkMultiplier,
        lessThanOrEqualTo(EconomyBalance.personalityTraitMax),
      );
      // Σ Blocktag = Wochenwert (V8): sieben Tagesschritte kosten exakt 7× Sink.
      var value = EconomyBalance.personalityTraitMax;
      for (var day = 0; day < 7; day++) {
        value =
            StressService.sink(value, EconomyBalance.resourceSinkPerDay).value;
      }
      expect(
        value,
        EconomyBalance.personalityTraitMax -
            7 * EconomyBalance.resourceSinkPerDay,
      );
    });

    test('Erschöpfung und Sink-Erleichterung bleiben gedeckelt (P7)', () {
      expect(EconomyBalance.resourceZeroMalusPerDay, greaterThan(0));
      expect(
        EconomyBalance.resourceZeroMalusPerDay,
        lessThan(EconomyBalance.resourceZeroMalusPerDayBoth),
        reason: 'Beide Ressourcen auf 0 ist härter als eine',
      );
      // Dokumentierte Spirale (`9` § 6): ~35 pp pro Nullwoche (eine Ressource)
      // bzw. ~70 pp (beide) – beides bleibt in der W100-Domäne.
      expect(
        7 * EconomyBalance.resourceZeroMalusPerDay,
        lessThanOrEqualTo(EconomyBalance.personalityTraitMax ~/ 2),
      );
      expect(
        7 * EconomyBalance.resourceZeroMalusPerDayBoth,
        lessThanOrEqualTo(EconomyBalance.personalityTraitMax),
      );
      // Ruheraum + Gewerkschaftschef können den Tages-Sink nie negativ machen.
      final lounge = EconomyBalance.upgrades[UpgradeType.lounge]!;
      final loungeReliefPercent =
          (lounge.dailySinkReliefPerLevel * lounge.maxLevel * 100).round();
      final unionReliefPercent =
          EconomyBalance.unionChiefSinkReductionPercentPerCompetence *
              EconomyBalance.featureCompetenceMax;
      expect(loungeReliefPercent + unionReliefPercent, lessThanOrEqualTo(100));
    });

    test('Trait-Ableitung ist symmetrisch und kollisionsfrei (P7)', () {
      expect(EconomyBalance.personalityTraitMin, 0);
      expect(EconomyBalance.personalityTraitMax, 100);
      // Die Varianz ist exakt ±range und damit unverzerrt.
      expect(
        EconomyBalance.personalityVarianceModulo,
        2 * EconomyBalance.personalityVarianceRange + 1,
      );
      expect(EconomyBalance.personalityVarianceRange, greaterThan(0));
      // Jedes Enneagramm-Profil hat einen eigenen Basis-Sockel.
      expect(
        EnneagramProfile.all.length * EconomyBalance.personalityTraitStep,
        lessThanOrEqualTo(EconomyBalance.personalityTraitModulo),
        reason: 'Zwei Profile würden auf demselben Sockel landen',
      );
      expect(EconomyBalance.personalityTraitStep, greaterThan(0));
      // Ein Trait wiegt nie schwerer als eine Stations-Spezialisierung.
      expect(EconomyBalance.combatTraitMaxPercent, greaterThan(0));
      expect(
        EconomyBalance.combatTraitMaxPercent,
        lessThanOrEqualTo(EconomyBalance.stationBonusMaxPercent.toDouble()),
      );
      // Die Persönlichkeit bleibt ein moderater Eingangs-Anteil (§ 8).
      expect(EconomyBalance.personalityAttractivenessWeight, greaterThan(0));
      expect(
        EconomyBalance.personalityAttractivenessWeight,
        lessThan(EconomyBalance.inputDomainMax),
      );
    });

    test('Stress-Staffel, Dauerleiter und Ruhe-Marge sind geordnet (P7)', () {
      expect(
        EconomyBalance.stressMarginSingleTick,
        lessThan(EconomyBalance.stressMarginDays),
      );
      expect(
        EconomyBalance.stressMarginDays,
        lessThan(EconomyBalance.stressMarginWeeks),
      );
      expect(
        EconomyBalance.stressMarginWeeks,
        lessThan(EconomyBalance.personalityTraitMax),
        reason: 'Auch die längste Stress-Staffel muss erreichbar bleiben',
      );
      expect(
        EconomyBalance.einzelTickUnit,
        lessThan(EconomyBalance.stressDayUnit),
      );
      expect(
        EconomyBalance.stressDayUnit,
        lessThan(EconomyBalance.stressWeekUnit),
      );
      expect(
        EconomyBalance.stressWeekUnit,
        lessThan(EconomyBalance.stressMonthUnit),
      );
      expect(EconomyBalance.stressDiceW6, greaterThan(1));
      expect(
        EconomyBalance.stressDiceW4,
        lessThanOrEqualTo(EconomyBalance.stressDiceW6),
      );

      // Die Ruhe greift erst bei einer echten Unterschreitung (nicht schon an
      // der ersten Stress-Staffel) und bleibt für den Median-Zielwert erreichbar.
      expect(
        EconomyBalance.ruheMargin,
        greaterThan(EconomyBalance.stressMarginSingleTick),
      );
      expect(
        EconomyBalance.ruheMargin,
        lessThanOrEqualTo(EconomyBalance.personalityTraitMax ~/ 2),
      );
      expect(
        EconomyBalance.personalityTraitMax ~/ 2 - EconomyBalance.ruheMargin,
        greaterThanOrEqualTo(EconomyBalance.d100Min),
        reason: 'Ruhe wäre für den Median-Zielwert nicht mehr erreichbar',
      );
    });

    test('Rolle ↔ Erweiterung: jede Zuordnung hat ihren Anker-Effekt (P7)', () {
      void anchored(
        String role,
        UpgradeType type,
        double Function(UpgradeSpec spec) effect,
      ) {
        final spec = EconomyBalance.upgrades[type];
        expect(spec, isNotNull, reason: 'Fehlende Erweiterung für $role');
        expect(
          effect(spec!),
          greaterThan(0),
          reason: '$role braucht $type als Wirkungsbasis',
        );
      }

      // Tabelle „Zuordnung Rolle ↔ Erweiterung“ (`11a`).
      anchored('Sommelier', UpgradeType.cellar,
          (s) => s.satisfactionBonusPerLevel);
      anchored('Lagerist', UpgradeType.coldRoom, (s) => s.capacityBonusPerLevel);
      anchored('Communard/Pâtissier/Gewerkschaftschef/Tournant',
          UpgradeType.lounge, (s) => s.refillBonusPerLevel);
      anchored('Communard/Pâtissier/Gewerkschaftschef/Tournant',
          UpgradeType.lounge, (s) => s.dailySinkReliefPerLevel);
      anchored('Rechtsanwalt', UpgradeType.certification,
          (s) => s.penaltyReductionPerLevel);
      anchored('Caissier', UpgradeType.vault,
          (s) => s.negativeInterestReliefPerLevel);
      // Die übrigen Anschaffungen sind ebenfalls echte Wirkungsbasen (P3).
      anchored('Teamarzt (Heilzeit)', UpgradeType.firstAid,
          (s) => s.healTimeReductionPerLevel);
      anchored('Fortbildung', UpgradeType.school,
          (s) => s.trainingCostReductionPerLevel);
      anchored('Sicherheitschef', UpgradeType.security,
          (s) => s.detectionBonusPerLevel);
      anchored('Sterneküche', UpgradeType.stars, (s) => s.prestigeBonusPerLevel);
      anchored('Sterneküche', UpgradeType.stars,
          (s) => s.sabotageTargetReliefPerLevel);

      // Jeder dieser Hebel gehört genau **einer** Erweiterung – sonst gäbe es
      // zwei Erweiterungen für dieselbe Rolle.
      void uniqueLever(double Function(UpgradeSpec spec) effect) {
        final owners = [
          for (final type in UpgradeType.values)
            if (effect(EconomyBalance.upgrades[type]!) > 0) type,
        ];
        expect(owners, hasLength(1), reason: 'Hebel mehrfach belegt: $owners');
      }

      uniqueLever((s) => s.negativeInterestReliefPerLevel);
      uniqueLever((s) => s.trainingCostReductionPerLevel);
      uniqueLever((s) => s.detectionBonusPerLevel);
      uniqueLever((s) => s.sabotageTargetReliefPerLevel);
      uniqueLever((s) => s.dailySinkReliefPerLevel);
      uniqueLever((s) => s.healTimeReductionPerLevel);
    });
  });
}
