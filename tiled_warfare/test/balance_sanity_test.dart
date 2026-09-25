import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/match_record.dart';
import 'package:tiled_warfare/models/medic_quality.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/models/restaurant_upgrade.dart';
import 'package:tiled_warfare/models/stations.dart';
import 'package:tiled_warfare/models/support_role.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/economy_service.dart';
import 'package:tiled_warfare/services/game_clock_service.dart';
import 'package:tiled_warfare/services/passive_income_service.dart';
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

    test('jede Erweiterung hat eine positive Spec mit mindestens einer Stufe',
        () {
      for (final type in UpgradeType.values) {
        final spec = EconomyBalance.upgrades[type];
        expect(spec, isNotNull, reason: 'Fehlende Spec für $type');
        expect(spec!.maxLevel, greaterThanOrEqualTo(1));
        expect(spec.buyBaseCost, greaterThan(0));
        expect(spec.upkeepBaseCostPerWeek, greaterThan(0));
      }
    });
  });

  group('Balance-Tuning: Einkommen & Zufriedenheit', () {
    RestaurantData restaurant({
      List<StaffData>? staff,
      MatchResult? result,
    }) =>
        RestaurantData(
          name: 'Balance',
          district: 'Harlem',
          staff: staff ?? [],
          lastMatchResult: result,
        );

    StaffData staff({
      String status = 'ready',
      int moneyValue = 100,
    }) =>
        StaffData(
          name: 'Testkoch',
          imagePath: 'assets/images/token/token_cook_basic.png',
          type: 'apprentice',
          status: status,
          moneyValue: moneyValue,
        );

    int passiveIncome(RestaurantData r) => PassiveIncomeService.passiveIncomePerWeek(
          attractiveness: GameClockService.attractivenessOf(r),
          satisfaction: GameClockService.satisfactionOf(r),
          capacity: GameClockService.capacityOf(r),
        );

    test('frisches Restaurant erwirtschaftet passiv Geld, aber weniger als ein Sieg',
        () {
      final fresh = restaurant(staff: [staff()]);
      final income = passiveIncome(fresh);

      expect(income, greaterThan(0));
      expect(income, lessThan(EconomyBalance.battleRewardBaseWin));
    });

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

    test('Maximal-Einkommen ist gedeckelt und unter üppigen Gefechtserlösen', () {
      final maxIncome = PassiveIncomeService.passiveIncomePerWeek(
        attractiveness: EconomyBalance.inputDomainMax,
        satisfaction: EconomyBalance.inputDomainMax,
        capacity: EconomyBalance.capacityMax,
      );

      expect(
        maxIncome,
        lessThanOrEqualTo(EconomyBalance.customersDomainMax *
            EconomyBalance.passiveIncomePerCustomerPerWeek),
      );

      final richBattle = EconomyService.battleReward(
        playerWon: true,
        enemyMoneyValues: const [1000, 1000, 1000],
      );
      expect(maxIncome, lessThan(richBattle));
    });
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
      for (var competence = EconomyBalance.featureCompetenceMin;
          competence <= EconomyBalance.featureCompetenceMax;
          competence++) {
        expect(ManagementFeatureService.boostPercentFor(competence),
            greaterThan(0));
      }
    });
  });
}
