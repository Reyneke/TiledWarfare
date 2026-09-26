import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/management_feature.dart';
import 'package:tiled_warfare/models/management_role.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/models/staff_entry.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/management_feature_service.dart';
import 'package:tiled_warfare/services/rival_service.dart';

/// Tests des **Minimal-Moduls** aus Kapitel 13 (V11): deterministischer
/// Rivalen-Roster je Stadtteil, Anzahl aus dem Prestige-Tier und Auflösung
/// einer Sabotage (`11a` E14).
void main() {
  final start = DateTime(2026, 1, 1);
  final rival = RivalService.rosterOf('Midtown').first;

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

  StaffEntryData lawyer({int id = 1}) => StaffEntryData(
        id: id,
        name: 'Anwalt',
        kind: RoleKind.management,
        role: ManagementRole.lawyer.name,
        costPerWeek:
            EconomyBalance.managementRoleWagePerWeek[ManagementRole.lawyer]!,
      );

  RestaurantData restaurant({
    List<StaffEntryData> entries = const [],
    int budget = 20000,
    DateTime? lastSeenAt,
  }) =>
      RestaurantData(
        id: 1,
        name: 'R',
        district: 'Midtown',
        budget: budget,
        lastSeenAt: lastSeenAt ?? start,
        weekAnchorAt: lastSeenAt ?? start,
        staffEntries: entries,
      );

  group('RivalService: Roster (Kapitel 13)', () {
    test('Anzahl folgt dem Prestige-Tier inkl. Grenzen', () {
      expect(RivalService.countFor('TriBeCa'), EconomyBalance.rivalCountS);
      expect(RivalService.countFor('SoHo'), EconomyBalance.rivalCountA);
      expect(RivalService.countFor('Chelsea'), EconomyBalance.rivalCountB);
      expect(RivalService.countFor('Midtown'), EconomyBalance.rivalCountC);
      expect(RivalService.countFor('Harlem'), EconomyBalance.rivalCountD);
      for (final district in ['TriBeCa', 'Harlem', 'Unbekannt', null]) {
        final count = RivalService.countFor(district);
        expect(count, greaterThanOrEqualTo(EconomyBalance.rivalCountMin));
        expect(count, lessThanOrEqualTo(EconomyBalance.rivalCountMax));
      }
    });

    test('Roster ist deterministisch (IDs, Persönlichkeit, Prestige)', () {
      final first = RivalService.rosterOf('Chelsea');
      final second = RivalService.rosterOf('Chelsea');
      expect(first.length, second.length);
      for (var i = 0; i < first.length; i++) {
        expect(first[i].id, second[i].id);
        expect(first[i].personalityId, second[i].personalityId);
        expect(first[i].basePrestige, second[i].basePrestige);
        expect(first[i].district, 'Chelsea');
      }
      // Unterschiedliche Stadtteile ⇒ unterschiedliche Rivalen-IDs.
      final other = RivalService.rosterOf('Harlem');
      expect(other.first.id, isNot(first.first.id));
    });

    test('byId findet Rivalen und liefert sonst null', () {
      final roster = RivalService.rosterOf('Midtown');
      expect(RivalService.byId(roster, roster.last.id)?.id, roster.last.id);
      expect(RivalService.byId(roster, null), isNull);
      expect(RivalService.byId(roster, -1), isNull);
    });

    test('Sabotage-Malus des Rivalen skaliert mit dem Prozentwert', () {
      expect(
        rival.sabotagedPrestige(
            EconomyBalance.sabotageRivalPrestigePenaltyPercent),
        closeTo(
          rival.basePrestige *
              (100 - EconomyBalance.sabotageRivalPrestigePenaltyPercent) /
              100,
          1e-9,
        ),
      );
      expect(
          rival.isSabotagedAt(
              rival.id, start.add(const Duration(days: 3)), start),
          isTrue);
      expect(
          rival.isSabotagedAt(
              rival.id, start.subtract(const Duration(days: 1)), start),
          isFalse);
      expect(
          rival.isSabotagedAt(
              null, start.add(const Duration(days: 3)), start),
          isFalse);
    });
  });

  group('Sabotage-Auflösung (`11a` E14)', () {
    /// ID eines Trägers mit deterministischem Erfolg/Misserfolg im Roster.
    ///
    /// Jeder Aufruf erzeugt einen **frischen** Eintrag – eine Aktivierung wird
    /// genau einmal aufgelöst (`featureResolvedAt`), also braucht jedes
    /// Restaurant im Test seine eigene Instanz.
    int findId(bool wantSuccess) {
      for (var id = 1; id <= 64; id++) {
        final owner = secretary(id: id, rivalId: rival.id, activatedAt: start);
        if (ManagementFeatureService.sabotageSucceeds(owner, rival.id) ==
            wantSuccess) {
          return id;
        }
      }
      fail('kein passender Sabotage-Fall im Roster gefunden');
    }

    StaffEntryData fresh(int id) =>
        secretary(id: id, rivalId: rival.id, activatedAt: start);

    test('Erfolgschance und Wurf sind deterministisch (Kompetenz 1–4)', () {
      final owner = fresh(1);
      final competence = ManagementFeatureService.competenceOf(owner);
      expect(
        ManagementFeatureService.sabotageSuccessPercentFor(owner),
        EconomyBalance.sabotageBaseSuccessPercent +
            competence * EconomyBalance.sabotageSuccessPercentPerStep,
      );
      final roll = ManagementFeatureService.sabotageRollFor(owner, rival.id);
      expect(roll, inInclusiveRange(0, 99));
      expect(ManagementFeatureService.sabotageRollFor(owner, rival.id), roll);
      expect(
        ManagementFeatureService.sabotageSucceeds(owner, rival.id),
        roll < ManagementFeatureService.sabotageSuccessPercentFor(owner),
      );
    });

    test('Erfolg öffnet das Wirkungsfenster und bucht keine Strafe', () {
      final owner = fresh(findId(true));
      final active = restaurant(entries: [owner]);
      final outcome = RivalService.resolveSabotage(
          active, owner, start.add(const Duration(days: 8)));
      expect(outcome, isNotNull);
      expect(outcome!.success, isTrue);
      expect(outcome.fine, 0);
      expect(active.sabotageTargetId, rival.id);
      expect(
        active.sabotageAppliedUntil,
        ManagementFeatureService.activeEndOf(owner)!
            .add(EconomyBalance.sabotageEffectDuration),
      );
      // Idempotent: dieselbe Aktivierung wird nicht erneut aufgelöst.
      expect(
        RivalService.resolveSabotage(
            active, owner, start.add(const Duration(days: 9))),
        isNull,
      );
      expect(
          RivalService.sabotageBonusActive(
              active, start.add(const Duration(days: 8))),
          isTrue);
      expect(
        RivalService.sabotageIncomeBonusPercent(
            active, start.add(const Duration(days: 8))),
        EconomyBalance.sabotageIncomeBonusPercent,
      );
    });

    test('Misserfolg kostet die Strafe – mit Rechtsanwalt gemindert', () {
      final id = findId(false);
      final now = start.add(const Duration(days: 8));

      final plain = restaurant(entries: [fresh(id)]);
      final plainOutcome =
          RivalService.resolveSabotage(plain, plain.staffEntries.first, now);
      expect(plainOutcome!.success, isFalse);
      expect(plainOutcome.grossFine, EconomyBalance.sabotageCaughtFine);
      expect(plainOutcome.fine, EconomyBalance.sabotageCaughtFine);
      expect(plain.sabotageTargetId, isNull);
      expect(plain.sabotageAppliedUntil, isNull);

      final mitigatedRestaurant = restaurant(entries: [fresh(id), lawyer()]);
      final mitigated = RivalService.resolveSabotage(
          mitigatedRestaurant, mitigatedRestaurant.staffEntries.first, now);
      expect(mitigated, isNotNull);
      expect(
        mitigated!.fine,
        (EconomyBalance.sabotageCaughtFine *
                (100 - EconomyBalance.lawyerPenaltyReductionPercent) /
                100)
            .round(),
      );
      expect(mitigated.fine, lessThan(mitigated.grossFine));
      // Die Auflösung selbst verändert das Budget nicht (Buchung im Tick).
      expect(mitigatedRestaurant.budget, 20000);
    });

    test('nicht fällige Sabotage wird nicht aufgelöst', () {
      final owner = secretary(
          id: 1,
          rivalId: rival.id,
          activatedAt: DateTime(2026, 3, 1));
      final pending = restaurant(entries: [owner]);
      expect(RivalService.resolveSabotage(pending, owner, start), isNull);
    });
  });
}
