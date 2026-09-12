import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/objects/object_team_medic.dart';
import 'package:tiled_warfare/objects/player_objects/object_apprentice.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/game_clock_service.dart';

/// Tests der Echtzeit-Heilung (V3, `3_Heilung_und_Zeit.md` § 7).
void main() {
  final base = DateTime(2026, 1, 1, 0);

  StaffData staff({
    String status = 'dying',
    DateTime? injuryStartedAt,
    DateTime? emergencyShotAt,
    String? suppressedStatus,
  }) =>
      StaffData(
        name: 'Testkoch',
        imagePath: 'x.png',
        type: 'apprentice',
        status: status,
        injuryStartedAt: injuryStartedAt,
        emergencyShotAt: emergencyShotAt,
        suppressedStatus: suppressedStatus,
      );

  RestaurantData restaurant({
    List<StaffData>? staffList,
    List<MedicData>? medics,
    DateTime? lastSeenAt,
  }) =>
      RestaurantData(
        name: 'Heiltest',
        staff: staffList ?? [],
        medics: medics ?? [],
        lastSeenAt: lastSeenAt,
      );

  MedicData medic(String quality) => MedicData(
        id: 1,
        name: 'Dr. X',
        quality: quality,
        costPerWeek: 500,
        enneagramProfileName: 'Der Chaot',
      );

  group('healTimePerStageFor', () {
    test('ohne Arzt 24 h, mit Qualität aus MedicQuality', () {
      expect(GameClockService.healTimePerStageFor(),
          EconomyBalance.healBasePerStage);
      expect(GameClockService.healTimePerStageFor(quality: MedicQuality.niedrig),
          const Duration(hours: 6));
      expect(GameClockService.healTimePerStageFor(quality: MedicQuality.mittel),
          const Duration(hours: 3));
      expect(GameClockService.healTimePerStageFor(quality: MedicQuality.hoch),
          const Duration(hours: 1));
    });
  });

  group('healedStatus (reine Vorwärtsrechnung)', () {
    const perStage = Duration(hours: 1);

    test('0 h heilt nicht', () {
      expect(
        GameClockService.healedStatus(
            CharacterStatus.dying, Duration.zero, perStage),
        CharacterStatus.dying,
      );
    });

    test('genau perStage heilt eine Stufe', () {
      expect(
        GameClockService.healedStatus(CharacterStatus.dying, perStage, perStage),
        CharacterStatus.injured,
      );
    });

    test('volle Kette in 5 Stufen bis ready', () {
      const chain = [
        CharacterStatus.dying,
        CharacterStatus.injured,
        CharacterStatus.hurt,
        CharacterStatus.afraid,
        CharacterStatus.reeling,
        CharacterStatus.ready,
      ];
      for (var i = 1; i < chain.length; i++) {
        expect(
          GameClockService.healedStatus(chain[0], perStage * i, perStage),
          chain[i],
          reason: 'Stufe $i',
        );
      }
    });

    test('30 Tage clamps auf ready', () {
      expect(
        GameClockService.healedStatus(
            CharacterStatus.dying, const Duration(days: 30), perStage),
        CharacterStatus.ready,
      );
    });

    test('dead/overkilled heilen nicht', () {
      expect(
        GameClockService.healedStatus(CharacterStatus.dead,
            const Duration(days: 30), perStage),
        CharacterStatus.dead,
      );
      expect(
        GameClockService.healedStatus(CharacterStatus.overkilled,
            const Duration(days: 30), perStage),
        CharacterStatus.overkilled,
      );
    });
  });

  group('heavierByChain (Kettenposition statt severity)', () {
    test('hurt ist schwerer als afraid', () {
      expect(
        GameClockService.heavierByChain(
            CharacterStatus.afraid, CharacterStatus.hurt),
        CharacterStatus.hurt,
      );
    });

    test('dying ist am schwersten innerhalb der Kette', () {
      expect(
        GameClockService.heavierByChain(
            CharacterStatus.reeling, CharacterStatus.dying),
        CharacterStatus.dying,
      );
    });
  });

  group('woundValueFor (Ableitung beim Gefechtsstart)', () {
    test('ready startet voll, Verletzungen geringer', () {
      expect(GameClockService.woundValueFor(CharacterStatus.ready),
          EconomyBalance.maxWoundValue);
      expect(GameClockService.woundValueFor(CharacterStatus.reeling), 2);
      expect(GameClockService.woundValueFor(CharacterStatus.hurt), 1);
      expect(GameClockService.woundValueFor(CharacterStatus.afraid), 1);
      expect(GameClockService.woundValueFor(CharacterStatus.dying), 1);
    });
  });

  group('advanceHealing', () {
    test('ohne Arzt 24 h pro Stufe', () {
      final r = restaurant(
        staffList: [staff(injuryStartedAt: base)],
      );
      GameClockService.advanceHealing(r, base.add(const Duration(hours: 24)));
      expect(r.staff.first.status, 'injured');
      GameClockService.advanceHealing(r, base.add(const Duration(hours: 48)));
      expect(r.staff.first.status, 'hurt');
    });

    test('mit hochwertigem Arzt 1 h pro Stufe', () {
      final r = restaurant(
        medics: [medic('hoch')],
        staffList: [staff(injuryStartedAt: base)],
      );
      GameClockService.advanceHealing(r, base.add(const Duration(hours: 2)));
      expect(r.staff.first.status, 'hurt');
    });

    test('ist idempotent (zweiter Aufruf heilt nicht doppelt)', () {
      final r = restaurant(
        medics: [medic('hoch')],
        staffList: [staff(injuryStartedAt: base)],
      );
      final now = base.add(const Duration(hours: 2));
      GameClockService.advanceHealing(r, now);
      final first = r.staff.first.status;
      GameClockService.advanceHealing(r, now);
      expect(r.staff.first.status, first);
    });

    test('Migration: Alt-Stand heilt rückwirkend ab lastSeenAt', () {
      final r = restaurant(
        lastSeenAt: base.subtract(const Duration(days: 5)),
        staffList: [staff()], // ohne injuryStartedAt
      );
      GameClockService.advanceHealing(r, base);
      expect(r.staff.first.status, 'ready');
    });

    test('ready bleibt ready', () {
      final r = restaurant(
        staffList: [staff(status: 'ready', injuryStartedAt: base)],
      );
      GameClockService.advanceHealing(r, base.add(const Duration(days: 10)));
      expect(r.staff.first.status, 'ready');
    });

    test('ist deterministisch (kein Fuzzy-Einfluss)', () {
      StaffData makeStaff() => staff(injuryStartedAt: base);
      final a = restaurant(medics: [medic('mittel')], staffList: [makeStaff()]);
      final b = restaurant(medics: [medic('mittel')], staffList: [makeStaff()]);
      final now = base.add(const Duration(hours: 7));
      GameClockService.advanceHealing(a, now);
      GameClockService.advanceHealing(b, now);
      expect(a.staff.first.status, b.staff.first.status);
    });
  });

  group('remainingHealingTime', () {
    test('ready hat keinen Countdown', () {
      expect(
        GameClockService.remainingHealingTime(
          status: CharacterStatus.ready,
          injuryStartedAt: base,
          perStage: const Duration(hours: 1),
          now: base,
        ),
        Duration.zero,
      );
    });

    test('zählt die Restzeit bis ready', () {
      // dying (5 Stufen) × 1 h, 2 h bereits vergangen → 3 h übrig.
      expect(
        GameClockService.remainingHealingTime(
          status: CharacterStatus.dying,
          injuryStartedAt: base,
          perStage: const Duration(hours: 1),
          now: base.add(const Duration(hours: 2)),
        ),
        const Duration(hours: 3),
      );
    });
  });
}
