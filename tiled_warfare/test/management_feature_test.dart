import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/management_feature.dart';
import 'package:tiled_warfare/models/management_role.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/models/staff_entry.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/economy_service.dart';
import 'package:tiled_warfare/services/game_clock_service.dart';
import 'package:tiled_warfare/services/management_feature_service.dart';

/// Tests der aktiven Personal-Features (`11a`): Kompetenz, Fenster
/// (aktiv/Nachteilphase), Tages-XP im Catch-up, Nachteile und Persistenz.
void main() {
  final start = DateTime(2026, 1, 1);
  const targetId = 4251;
  final activeEnd = start.add(EconomyBalance.featureActiveDuration);
  final aftermathEnd = activeEnd.add(EconomyBalance.featureAftermathDuration);

  StaffEntryData managerEntry({
    DateTime? activatedAt,
    int? target = targetId,
    int id = 1,
  }) =>
      StaffEntryData(
        id: id,
        name: 'Mia',
        kind: RoleKind.management,
        role: ManagementRole.socialMediaManager.name,
        costPerWeek: 180,
        activeFeature:
            activatedAt == null ? null : ManagementFeature.prCampaign.name,
        featureTargetId: activatedAt == null ? null : target,
        featureActivatedAt: activatedAt,
      );

  StaffData chef({int id = targetId, int level = 3, int xp = 0}) => StaffData(
        name: 'Koch',
        imagePath: 'x.png',
        type: kRankApprentice,
        rank: kRankApprentice,
        id: id,
        personalityId: 2,
        levelValue: level,
        currentXPValue: xp,
        // Ressourcen wie in einem geladenen Spielstand (sonst greifen die
        // Tages-Sinks nicht, weil Alt-Daten `null` tragen).
        vitalityCurrent: 50,
        moraleCurrent: 50,
      );

  RestaurantData restaurant({
    List<StaffEntryData> entries = const [],
    List<StaffData>? staff,
  }) =>
      RestaurantData(
        id: 1,
        name: 'R',
        district: 'Harlem',
        budget: 10000,
        lastSeenAt: start,
        weekAnchorAt: start,
        staffEntries: entries,
        staff: staff ?? [chef()],
      );

  group('ManagementFeatureService (11a)', () {
    test('Kompetenz ist deterministisch und in der Domäne', () {
      for (var id = 1; id <= 20; id++) {
        final competence =
            ManagementFeatureService.competenceOf(managerEntry(id: id));
        expect(competence,
            greaterThanOrEqualTo(EconomyBalance.featureCompetenceMin));
        expect(competence,
            lessThanOrEqualTo(EconomyBalance.featureCompetenceMax));
        expect(
            ManagementFeatureService.competenceOf(managerEntry(id: id)),
            competence);
      }
      expect(
        ManagementFeatureService.boostPercentFor(1),
        EconomyBalance.featureCompetenceBoostPercentPerStep,
      );
    });

    test('Kosten skalieren mit dem Level des Ziels', () {
      expect(
        ManagementFeatureService.featureCostFor(3),
        3 * EconomyBalance.featureCostPerLevel,
      );
      expect(
        ManagementFeatureService.featureCostFor(0),
        EconomyBalance.featureCostPerLevel,
      );
    });

    test('Fenster: aktiv (inklusiv), Nachteilphase, beendet', () {
      final entries = [managerEntry(activatedAt: start)];
      const feature = ManagementFeature.prCampaign;

      expect(ManagementFeatureService.isActive(entries, feature, start), isTrue);
      expect(ManagementFeatureService.isActive(entries, feature, activeEnd),
          isTrue);
      expect(
        ManagementFeatureService.isActive(entries, feature,
            activeEnd.add(const Duration(hours: 1))),
        isFalse,
      );

      expect(
          ManagementFeatureService.aftermathEntry(entries, feature, activeEnd),
          isNull);
      expect(
        ManagementFeatureService.aftermathEntry(
            entries, feature, activeEnd.add(const Duration(days: 1))),
        isNotNull,
      );
      expect(
        ManagementFeatureService.aftermathEntry(entries, feature,
            aftermathEnd.add(const Duration(hours: 1))),
        isNull,
      );

      expect(
          ManagementFeatureService.isFinished(entries.single, aftermathEnd),
          isFalse);
      expect(
        ManagementFeatureService.isFinished(
            entries.single, aftermathEnd.add(const Duration(hours: 1))),
        isTrue,
      );
    });

    test('Nachteil-Faktoren wirken nur auf das Ziel', () {
      final entries = [managerEntry(activatedAt: start)];
      final inAftermath = activeEnd.add(const Duration(days: 1));
      expect(
        ManagementFeatureService.refillFractionFor(
            entries, targetId, inAftermath),
        EconomyBalance.featureAftermathRefillFraction,
      );
      expect(
          ManagementFeatureService.refillFractionFor(entries, targetId, activeEnd),
          1.0);
      expect(
        ManagementFeatureService.aftermathSinkMultipliers(
            entries, inAftermath)[targetId],
        EconomyBalance.featureAftermathSinkMultiplier,
      );
      expect(
        ManagementFeatureService.aftermathSinkMultipliers(entries, activeEnd),
        isEmpty,
      );
    });

    test('ohne Träger gibt es keine Wirkung', () {
      expect(
        ManagementFeatureService.ownerOf(const [], ManagementFeature.prCampaign),
        isNull,
      );
      expect(
        ManagementFeatureService.xpBoostPercentFor(const [], targetId, start),
        0,
      );
      expect(
        ManagementFeatureService.aftermathSinkMultipliers(const [], start),
        isEmpty,
      );
    });
  });

  group('Catch-up: aktive Phase (11a)', () {
    test('eine Woche schüttet 7 Tagesticks XP "wie ein Sieg" (+Kompetenz) aus',
        () {
      final entries = [managerEntry(activatedAt: start)];
      final r = restaurant(entries: entries);
      final bonus = ManagementFeatureService.boostPercentFor(
          ManagementFeatureService.competenceOf(entries.single));
      final expected = 7 *
          EconomyService.boostedXp(
              EconomyService.xpForBattle(won: true, level: 3), bonus);

      GameClockService.catchUp(r, activeEnd);

      expect(r.staff.single.currentXPValue, expected);
      expect(r.staff.single.levelValue, 3,
          reason: '728 XP liegen unter der Schwelle 3 × 1000');
    });

    test('Idempotenz: zweiter Aufruf mit gleichem now bucht nichts', () {
      final entries = [managerEntry(activatedAt: start)];
      final r = restaurant(entries: entries);
      GameClockService.catchUp(r, activeEnd);
      final xpAfterFirst = r.staff.single.currentXPValue;

      final second = GameClockService.catchUp(r, activeEnd);

      expect(second.weeks, 0);
      expect(second.leftoverDays, 0);
      expect(r.staff.single.currentXPValue, xpAfterFirst);
    });

    test('ohne Feature gibt es keine Tages-XP im Catch-up', () {
      final r = restaurant();
      GameClockService.catchUp(r, activeEnd);
      expect(r.staff.single.currentXPValue, 0);
    });
  });

  group('Catch-up: Nachteilphase (11a)', () {
    // Zwei identisch aufgebaute Restaurants – nur das Feature unterscheidet sie.
    RestaurantData withFeature() =>
        restaurant(entries: [managerEntry(activatedAt: start)]);
    RestaurantData withoutFeature() => restaurant();

    test('Ziel sinkt stärker und regeneriert nur halb', () {
      final boosted = withFeature();
      final plain = withoutFeature();
      // Volle Nachteilphase: aktive Woche + Nachwirkungswoche.
      final at = aftermathEnd;

      GameClockService.catchUp(boosted, at);
      GameClockService.catchUp(plain, at);

      expect(
        boosted.staff.single.vitalityCurrent,
        lessThan(plain.staff.single.vitalityCurrent!),
      );
      expect(
        boosted.staff.single.moraleCurrent,
        lessThan(plain.staff.single.moraleCurrent!),
      );
      expect(plain.staff.single.vitalityCurrent,
          greaterThan(EconomyBalance.resourceMin));
    });

    test('abgelaufenes Feature wird zurückgesetzt (neu aktivierbar)', () {
      final entries = [managerEntry(activatedAt: start)];
      final r = restaurant(entries: entries);
      GameClockService.catchUp(
          r, aftermathEnd.add(const Duration(days: 1)));

      expect(entries.single.activeFeature, isNull);
      expect(entries.single.featureTargetId, isNull);
      expect(entries.single.featureActivatedAt, isNull);
    });
  });

  group('Persistenz (11a)', () {
    test('Feature-Felder überleben den JSON-Roundtrip', () {
      final entry = managerEntry(activatedAt: start);
      final restored = StaffEntryData.fromJson(entry.toJson());

      expect(restored.activeFeature, ManagementFeature.prCampaign.name);
      expect(restored.featureTargetId, targetId);
      expect(restored.featureActivatedAt, start);

      final legacy = StaffEntryData.fromJson({'name': 'Alt'});
      expect(legacy.activeFeature, isNull);
      expect(legacy.featureTargetId, isNull);
      expect(legacy.featureActivatedAt, isNull);
    });
  });

  group('Aktivierung (ObjectProfile, 11a)', () {
    void load({
      List<StaffData> staff = const [],
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
              district: 'Harlem',
              budget: budget,
              lastSeenAt: start,
              weekAnchorAt: start,
              staff: staff,
              staffEntries: entries,
            ),
          ],
        ),
        restaurantId: 1,
      );
    }

    test('bucht die Einmalkosten sofort und blockiert die Doppelaktivierung',
        () {
      load(staff: [chef()], entries: [managerEntry()]);
      final profile = ObjectProfile();
      final target = profile.personal.single;

      expect(profile.managementFeatureCostFor(target),
          3 * EconomyBalance.featureCostPerLevel);

      expect(
        profile.activateManagementFeature(ManagementFeature.prCampaign, target,
            now: start),
        isTrue,
      );
      expect(profile.budget, 10000 - 3000);
      expect(
        profile.managementFeatureIsActive(ManagementFeature.prCampaign,
            now: start),
        isTrue,
      );
      expect(
        profile.activateManagementFeature(ManagementFeature.prCampaign, target,
            now: start),
        isFalse,
      );
    });

    test('runCatchUp schreibt die Feature-XP in die In-Memory-Charaktere', () {
      load(staff: [chef()], entries: [managerEntry()]);
      final profile = ObjectProfile();
      final target = profile.personal.single;
      expect(
        profile.activateManagementFeature(
            ManagementFeature.prCampaign, target,
            now: start),
        isTrue,
      );

      profile.runCatchUp(activeEnd);

      expect(profile.personal.single.currentXPValue, greaterThan(0));
      expect(profile.personal.single.levelValue, 3);
    });

    test('ohne Träger oder ohne Budget wird nicht aktiviert', () {
      // Kein Feature-Träger angestellt.
      load(staff: [chef()]);
      final profile = ObjectProfile();
      expect(
        profile.activateManagementFeature(
            ManagementFeature.prCampaign, profile.personal.single,
            now: start),
        isFalse,
      );

      // Träger vorhanden, aber die Kosten sprengen die Negativgrenze.
      load(
        staff: [chef()],
        entries: [managerEntry()],
        budget: EconomyBalance.negativeLimit + 500,
      );
      final broke = ObjectProfile();
      expect(
        broke.activateManagementFeature(
            ManagementFeature.prCampaign, broke.personal.single,
            now: start),
        isFalse,
      );
    });
  });
}
