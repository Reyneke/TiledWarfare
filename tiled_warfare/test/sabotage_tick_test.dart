import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/management_feature.dart';
import 'package:tiled_warfare/models/management_role.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/models/restaurant_upgrade.dart';
import 'package:tiled_warfare/models/staff_entry.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/game_clock_service.dart';
import 'package:tiled_warfare/services/management_feature_service.dart';
import 'package:tiled_warfare/services/rival_service.dart';

/// Wochentick-Tests der Verwaltungsrollen (`11a` E12/E14/E16): passive
/// Kostenminderung, Kreative Buchführung (tagesgenaue Negation) und die
/// Auflösung einer Sabotage inklusive Strafe und Einkommens-Fenster.
void main() {
  final start = DateTime(2026, 1, 1);
  final rival = RivalService.rosterOf('Midtown').first;

  StaffEntryData management(ManagementRole role, {int id = 1, int? cost}) =>
      StaffEntryData(
        id: id,
        name: role.name,
        kind: RoleKind.management,
        role: role.name,
        costPerWeek:
            cost ?? EconomyBalance.managementRoleWagePerWeek[role] ?? 0,
      );

  StaffEntryData accountantWithAccounting({int id = 3, DateTime? at}) =>
      StaffEntryData(
        id: id, // competenceOf(3) == 4 ⇒ vier Tage Negation
        name: 'Buchhalter',
        kind: RoleKind.management,
        role: ManagementRole.accountant.name,
        costPerWeek:
            EconomyBalance.managementRoleWagePerWeek[ManagementRole.accountant]!,
        activeFeature:
            at == null ? null : ManagementFeature.creativeAccounting.name,
        featureActivatedAt: at,
      );

  StaffEntryData secretary({
    required int id,
    int? rivalId,
    DateTime? activatedAt,
  }) =>
      StaffEntryData(
        id: id,
        name: 'Sekretärin',
        kind: RoleKind.management,
        role: ManagementRole.chefSecretary.name,
        costPerWeek: EconomyBalance.managementRoleWagePerWeek[
            ManagementRole.chefSecretary]!,
        activeFeature:
            activatedAt == null ? null : ManagementFeature.sabotage.name,
        featureTargetId: activatedAt == null ? null : rivalId,
        featureActivatedAt: activatedAt,
      );

  RestaurantData restaurant({List<StaffEntryData> entries = const []}) =>
      RestaurantData(
        id: 1,
        name: 'R',
        district: 'Midtown',
        budget: 20000,
        lastSeenAt: start,
        weekAnchorAt: start,
        staffEntries: entries,
        staff: [
          StaffData(
            name: 'Koch',
            imagePath: 'x.png',
            type: kRankApprentice,
            rank: kRankApprentice,
            id: 42,
            personalityId: 2,
            levelValue: 3,
            currentXPValue: 0,
            vitalityCurrent: 50,
            moraleCurrent: 50,
          ),
        ],
        medics: [
          MedicData(
            id: 7,
            name: 'Dr',
            quality: 'niedrig',
            costPerWeek: 500,
            enneagramProfileName: 'Helfer',
          ),
        ],
        upgrades: {UpgradeType.tables: 2},
      );

  group('Passive Kostenminderung im Wochentick (E12)', () {
    test('Chefsekretärin (−5 %) und Buchhalter (−5 %) mindern die Löhne', () {
      final baseline = restaurant();
      final baselineResult =
          GameClockService.catchUp(baseline, start.add(const Duration(days: 7)));

      final withRoles = restaurant(entries: [
        management(ManagementRole.chefSecretary),
        management(ManagementRole.accountant, id: 2),
      ]);
      final result =
          GameClockService.catchUp(withRoles, start.add(const Duration(days: 7)));

      // Löhne: −10 % (Chefsekretärin + „alle laufenden Kosten“ des Buchhalters)
      // auf die **gesamte** Lohnsumme inklusive der beiden Rollen selbst.
      final rawWage = baselineResult.staffCosts +
          EconomyBalance.managementRoleWagePerWeek[
              ManagementRole.chefSecretary]! +
          EconomyBalance.managementRoleWagePerWeek[ManagementRole.accountant]!;
      expect(result.staffCosts, (rawWage * 90 / 100).round());
      // Arztkosten und Erweiterungs-Unterhalt: −5 % (Buchhalter).
      expect(result.medicCosts, (baselineResult.medicCosts * 95 / 100).round());
      expect(
        result.upgradeUpkeep,
        (baselineResult.upgradeUpkeep * 95 / 100).round(),
      );
      expect(result.staffCosts, lessThan(rawWage));
      expect(result.penaltyCosts, 0);
    });

    test('ohne die Rollen bleibt die Abrechnung unverändert', () {
      final baseline = restaurant();
      final result =
          GameClockService.catchUp(baseline, start.add(const Duration(days: 7)));
      expect(result.medicCosts, baseline.medics.first.costPerWeek);
      expect(result.staffCosts, greaterThan(0));
      expect(result.upgradeUpkeep, greaterThan(0));
    });
  });

  group('Kreative Buchführung im Wochentick (E16)', () {
    test('negiert die laufenden Kosten tagesanteilig (Kompetenz 4 ⇒ 4 Tage)',
        () {
      // Vergleichsrestaurant: identische Buchhalter-Rolle **ohne** aktives
      // Feature ⇒ nur die Tages-Negation unterscheidet beide Abrechnungen.
      final idle = restaurant(entries: [accountantWithAccounting()]);
      final idleResult =
          GameClockService.catchUp(idle, start.add(const Duration(days: 7)));

      final active = restaurant(entries: [
        accountantWithAccounting(at: start),
      ]);
      final result =
          GameClockService.catchUp(active, start.add(const Duration(days: 7)));

      expect(ManagementFeatureService.competenceOf(active.staffEntries.first),
          4);
      int expected(int full) => full - (full * 4 / 7).round();
      expect(result.staffCosts, expected(idleResult.staffCosts));
      expect(result.medicCosts, expected(idleResult.medicCosts));
      expect(result.upgradeUpkeep, expected(idleResult.upgradeUpkeep));
      expect(
        result.settlements.first.staffCosts,
        expected(idleResult.settlements.first.staffCosts),
      );
      expect(result.staffCosts, lessThan(idleResult.staffCosts));
    });

    test('Burnout-Fenster verhindert eine erneute Aktivierung (Nachteilphase)',
        () {
      final entry = accountantWithAccounting(at: start);
      final restaurant0 = restaurant(entries: [entry]);
      GameClockService.catchUp(restaurant0, start.add(const Duration(days: 7)));
      // Nach der aktiven Phase läuft die Burnout-Nachteilphase: gleiche Länge
      // wie die aktive Phase (Kompetenz × 1 Tag).
      expect(
        ManagementFeatureService.aftermathDurationOf(entry),
        EconomyBalance.creativeAccountingAftermathPerCompetence * 4,
      );
      expect(entry.activeFeature, ManagementFeature.creativeAccounting.name);
      // Erst nach dem Burnout wird das Feature zurückgesetzt.
      GameClockService.catchUp(
        restaurant0,
        start.add(const Duration(days: 8) + EconomyBalance.dailyTick * 4),
      );
      expect(entry.activeFeature, isNull);
    });
  });

  group('Sabotage-Auflösung im Wochentick (E14)', () {
    /// ID eines Trägers mit deterministischem Erfolg/Misserfolg im Roster.
    ///
    /// Jeder Aufruf erzeugt einen **frischen** Eintrag: eine Aktivierung wird
    /// genau einmal aufgelöst (`featureResolvedAt`), Tests brauchen also je
    /// Restaurant eine eigene Instanz.
    int findId(bool wantSuccess) {
      for (var id = 1; id <= 64; id++) {
        final owner =
            secretary(id: id, rivalId: rival.id, activatedAt: start);
        if (ManagementFeatureService.sabotageSucceeds(owner, rival.id) ==
            wantSuccess) {
          return id;
        }
      }
      fail('kein passender Sabotage-Fall im Roster gefunden');
    }

    StaffEntryData fresh(int id) =>
        secretary(id: id, rivalId: rival.id, activatedAt: start);

    test('Misserfolg: Strafe wird gebucht, mit Rechtsanwalt gemindert', () {
      final id = findId(false);
      final now = start.add(const Duration(days: 8));

      final plain = restaurant(entries: [fresh(id)]);
      final plainResult = GameClockService.catchUp(plain, now);
      expect(plainResult.penaltyCosts, EconomyBalance.sabotageCaughtFine);
      expect(
        plainResult.settlements.first.penaltyCosts,
        EconomyBalance.sabotageCaughtFine,
      );
      expect(plain.sabotageAppliedUntil, isNull);

      final guarded = restaurant(entries: [
        fresh(id),
        management(ManagementRole.lawyer, id: 9),
      ]);
      final guardedResult = GameClockService.catchUp(guarded, now);
      expect(
        guardedResult.penaltyCosts,
        (EconomyBalance.sabotageCaughtFine *
                (100 - EconomyBalance.lawyerPenaltyReductionPercent) /
                100)
            .round(),
      );
      expect(
        guardedResult.penaltyCosts,
        lessThan(plainResult.penaltyCosts),
      );
      // Idempotent: derselbe Catch-up bucht die Strafe kein zweites Mal.
      expect(GameClockService.catchUp(guarded, now).penaltyCosts, 0);
    });

    test('Erfolg: Wirkungsfenster hebt das Einkommen im nächsten Tick', () {
      final id = findId(true);
      final withSabotage = restaurant(entries: [fresh(id)]);
      final resolved = GameClockService.catchUp(
          withSabotage, start.add(const Duration(days: 8)));
      expect(resolved.penaltyCosts, 0);
      expect(withSabotage.sabotageTargetId, rival.id);
      expect(withSabotage.sabotageAppliedUntil, isNotNull);

      // Kontrolle: identischer Aufbau, aber ohne Wirkungsfenster.
      final control = restaurant(entries: [fresh(id)]);
      GameClockService.catchUp(control, start.add(const Duration(days: 8)));
      control.sabotageTargetId = null;
      control.sabotageAppliedUntil = null;

      final withBonus = GameClockService.catchUp(
          withSabotage, start.add(const Duration(days: 15)));
      final withoutBonus = GameClockService.catchUp(
          control, start.add(const Duration(days: 15)));
      expect(withBonus.passiveIncome, greaterThan(withoutBonus.passiveIncome));
      // Die Kosten bleiben unverändert (der Bonus wirkt nur auf das Einkommen).
      expect(withBonus.staffCosts, withoutBonus.staffCosts);
      expect(withBonus.medicCosts, withoutBonus.medicCosts);
    });
  });
}
