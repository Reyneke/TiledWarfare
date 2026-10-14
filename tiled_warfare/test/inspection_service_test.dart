import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/management_feature.dart';
import 'package:tiled_warfare/models/management_role.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/models/restaurant_upgrade.dart';
import 'package:tiled_warfare/models/staff_entry.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/game_clock_service.dart';
import 'package:tiled_warfare/services/inspection_service.dart';

/// Tests der **Behörden-Inspektion** (P3, `11a` „Behörden/Inspektionen“): der
/// zweiten, passiven Strafenquelle neben der aufgedeckten Sabotage. Sie macht
/// die Erweiterung **Zertifizierung/Hygiene-Siegel** (`11b` Gruppe D) auch für
/// defensive Spielweisen wertvoll.
void main() {
  final start = DateTime(2026, 1, 1, 12);

  StaffEntryData management(ManagementRole role, {int id = 1}) =>
      StaffEntryData(
        id: id,
        name: role.name,
        kind: RoleKind.management,
        role: role.name,
        costPerWeek: EconomyBalance.managementRoleWagePerWeek[role] ?? 0,
      );

  /// Rechtsanwalt mit aktivem Winkelzug (`id` 3 ⇒ Kompetenz 4 ⇒ 100 %).
  StaffEntryData lawyerWithTrick({required DateTime at}) => StaffEntryData(
    id: 3,
    name: ManagementRole.lawyer.name,
    kind: RoleKind.management,
    role: ManagementRole.lawyer.name,
    costPerWeek:
        EconomyBalance.managementRoleWagePerWeek[ManagementRole.lawyer]!,
    activeFeature: ManagementFeature.legalTrick.name,
    featureActivatedAt: at,
  );

  RestaurantData restaurant({
    int id = 1,
    int budget = 20000,
    List<StaffEntryData> entries = const [],
    Map<UpgradeType, int> upgrades = const {},
    double corruptionPercent = 0,
  }) => RestaurantData(
    id: id,
    name: 'R',
    district: 'Midtown',
    budget: budget,
    lastSeenAt: start,
    weekAnchorAt: start,
    staffEntries: entries,
    upgrades: upgrades,
    corruptionPercent: corruptionPercent,
  );

  /// Erster Blockanker ab [from], in dem für [restaurantId] eine Inspektion
  /// fällig ist (deterministisch über Intervall + Restaurant-Phase).
  DateTime dueAnchor(int restaurantId, {DateTime? from}) {
    var anchor = from ?? DateTime(2026, 3, 4);
    for (var i = 0; i <= EconomyBalance.inspectionIntervalWeeks; i++) {
      if (InspectionService.isDue(
        restaurantId: restaurantId,
        blockAnchor: anchor,
      )) {
        return anchor;
      }
      anchor = anchor.add(const Duration(days: 7));
    }
    fail('kein fälliger Block gefunden');
  }

  group('InspectionService Zeitplan (deterministisch, V8)', () {
    test('Phase liegt im Intervall und ist wiederholbar', () {
      for (final id in [1, 2, 42, 1000]) {
        final phase = InspectionService.phaseOf(id);
        expect(
          phase,
          inInclusiveRange(0, EconomyBalance.inspectionIntervalWeeks - 1),
        );
        expect(InspectionService.phaseOf(id), phase);
      }
    });

    test('genau ein Block je Intervall ist fällig', () {
      final interval = EconomyBalance.inspectionIntervalWeeks;
      for (final id in [1, 2, 7, 99]) {
        var anchor = DateTime(2026, 3, 4);
        var due = 0;
        for (var i = 0; i < interval; i++) {
          if (InspectionService.isDue(restaurantId: id, blockAnchor: anchor)) {
            due++;
          }
          anchor = anchor.add(const Duration(days: 7));
        }
        expect(due, 1, reason: 'Restaurant $id');
      }
    });

    test('gleiche Eingaben ⇒ gleiches Ergebnis (kein Zufall)', () {
      final anchor = DateTime(2026, 5, 6);
      expect(
        InspectionService.isDue(restaurantId: 5, blockAnchor: anchor),
        InspectionService.isDue(restaurantId: 5, blockAnchor: anchor),
      );
    });
  });

  group('InspectionService Strafe (Korruptions-Zuschlag)', () {
    final base = EconomyBalance.inspectionFineBase;

    test('ohne Korruption fällt die Basisstrafe an', () {
      expect(InspectionService.grossFine(corruptionPercent: 0), base);
    });

    test('halbe Korruption erhöht die Strafe um die Hälfte', () {
      expect(
        InspectionService.grossFine(corruptionPercent: 50),
        (base * 1.5).round(),
      );
    });

    test('volle Korruption verdoppelt die Strafe', () {
      expect(InspectionService.grossFine(corruptionPercent: 100), base * 2);
    });

    test('Korruption über 100 % wird geklemmt', () {
      expect(InspectionService.grossFine(corruptionPercent: 150), base * 2);
    });
  });

  group('InspectionService.resolve', () {
    test('nicht fälliger Block ⇒ null', () {
      final anchor = dueAnchor(1, from: DateTime(2026, 3, 4));
      final before = anchor.subtract(const Duration(days: 7));
      expect(
        InspectionService.isDue(restaurantId: 1, blockAnchor: before),
        isFalse,
      );
      expect(InspectionService.resolve(restaurant(), before), isNull);
    });

    test('fälliger Block ohne Minderung bucht die Bruttostrafe', () {
      final anchor = dueAnchor(1);
      final outcome = InspectionService.resolve(
        restaurant(),
        anchor,
        corruptionPercent: 0,
      );
      expect(outcome, isNotNull);
      expect(outcome!.blockAnchor, anchor);
      expect(outcome.reductionPercent, 0);
      expect(outcome.fine, outcome.grossFine);
      expect(outcome.fine, EconomyBalance.inspectionFineBase);
    });

    test('Zertifizierung und Rechtsanwalt stapeln additiv (−40 %)', () {
      final anchor = dueAnchor(1);
      final outcome = InspectionService.resolve(
        restaurant(
          entries: [management(ManagementRole.lawyer)],
          upgrades: {UpgradeType.certification: 3},
        ),
        anchor,
        corruptionPercent: 100,
      )!;
      // 25 % (Rechtsanwalt) + 15 % (Zertifizierung) = 40 %.
      expect(outcome.reductionPercent, 40);
      expect(outcome.grossFine, EconomyBalance.inspectionFineBase * 2);
      expect(outcome.fine, (outcome.grossFine * 60 / 100).round());
    });

    test('volle Minderung (Winkelzug K4 + Rechtsanwalt + Zertifizierung) ⇒ 0 €',
        () {
      final anchor = dueAnchor(1);
      final at = anchor.add(const Duration(days: 1));
      final outcome = InspectionService.resolve(
        restaurant(
          entries: [lawyerWithTrick(at: at)],
          upgrades: {UpgradeType.certification: 3},
        ),
        anchor,
        now: at,
        corruptionPercent: 10,
      )!;
      // 100 % (Winkelzug) + 25 % + 15 % ⇒ auf 100 % gedeckelt.
      expect(outcome.reductionPercent, 100);
      expect(outcome.fine, 0);
    });
  });

  group('GameClockService.catchUp (Integration, P3)', () {
    test('nur die fälligen Blöcke buchen eine Inspektion', () {
      final r = restaurant();
      final result =
          GameClockService.catchUp(r, start.add(const Duration(days: 7 * 8)));

      expect(result.settlements.length, 8);
      final booked = [
        for (var i = 0; i < result.settlements.length; i++)
          if (result.settlements[i].penaltyCosts > 0) i,
      ];
      final expected = [
        for (var i = 0; i < result.settlements.length; i++)
          if (InspectionService.isDue(
            restaurantId: r.id,
            blockAnchor: result.settlements[i].periodStart,
          ))
            i,
      ];
      expect(booked, isNotEmpty);
      expect(booked, expected);
      // Jede Strafe liegt mindestens auf der Basis (Korruption ≥ 1 %).
      for (final settlement in result.settlements) {
        if (settlement.penaltyCosts == 0) continue;
        expect(
          settlement.penaltyCosts,
          greaterThanOrEqualTo(EconomyBalance.inspectionFineBase),
        );
      }
    });

    test('die Zertifizierung mindert die Strafbuchungen des Ticks', () {
      final plain = restaurant();
      final plainResult =
          GameClockService.catchUp(plain, start.add(const Duration(days: 56)));

      final certified = restaurant(upgrades: {UpgradeType.certification: 3});
      final certifiedResult = GameClockService.catchUp(
        certified,
        start.add(const Duration(days: 56)),
      );

      expect(plainResult.penaltyCosts, greaterThan(0));
      // −15 % je Einzelstrafe, kaufmännisch gerundet (nicht auf der Summe).
      var expected = 0;
      for (final settlement in plainResult.settlements) {
        if (settlement.penaltyCosts == 0) continue;
        expected += (settlement.penaltyCosts * 85 / 100).round();
      }
      expect(certifiedResult.penaltyCosts, expected);
      expect(certifiedResult.penaltyCosts, lessThan(plainResult.penaltyCosts));
    });
  });
}
