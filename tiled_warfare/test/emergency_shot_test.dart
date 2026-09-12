import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/objects/player_objects/object_apprentice.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/game_clock_service.dart';

/// Tests der automatischen Notfall-Spritze und ihres Rückfalls (V3, § 7).
void main() {
  final base = DateTime(2026, 1, 1, 0);

  StaffData shotStaff({
    String status = 'ready',
    String suppressed = 'dying',
    DateTime? injuryStartedAt,
    DateTime? emergencyShotAt,
  }) =>
      StaffData(
        name: 'Verwundeter',
        imagePath: 'x.png',
        type: 'apprentice',
        status: status,
        injuryStartedAt: injuryStartedAt,
        emergencyShotAt: emergencyShotAt,
        suppressedStatus: suppressed,
      );

  RestaurantData restaurant({List<StaffData>? staffList}) => RestaurantData(
        name: 'Spritztest',
        staff: staffList ?? [],
      );

  group('rollBackEmergencyShots', () {
    test('vor Ablauf der Wirkungsdauer kein Rückfall', () {
      final r = restaurant(staffList: [
        shotStaff(emergencyShotAt: base, injuryStartedAt: base),
      ]);
      final n = GameClockService.rollBackEmergencyShots(
          r, base.add(const Duration(hours: 23)));
      expect(n, 0);
      expect(r.staff.first.status, 'ready');
      expect(r.staff.first.emergencyShotAt, isNotNull);
    });

    test('nach 24 h kehrt der unterdrückte Status zurück', () {
      final now = base.add(const Duration(hours: 25));
      final r = restaurant(staffList: [
        shotStaff(emergencyShotAt: base, injuryStartedAt: base),
      ]);
      final n = GameClockService.rollBackEmergencyShots(r, now);
      expect(n, 1);
      expect(r.staff.first.status, 'dying');
      expect(r.staff.first.injuryStartedAt, now);
      expect(r.staff.first.emergencyShotAt, isNull);
      expect(r.staff.first.suppressedStatus, isNull);
    });

    test('ist idempotent (zweiter Aufruf nimmt nichts weiter zurück)', () {
      final now = base.add(const Duration(hours: 25));
      final r = restaurant(staffList: [
        shotStaff(emergencyShotAt: base, injuryStartedAt: base),
      ]);
      GameClockService.rollBackEmergencyShots(r, now);
      final second = GameClockService.rollBackEmergencyShots(r, now);
      expect(second, 0);
      expect(r.staff.first.status, 'dying');
    });

    test('schwererer zwischenzeitlicher Status gewinnt (Kette)', () {
      // Unterdrückt war `afraid`, zwischenzeitlich `hurt` (schwerer) → hurt.
      final now = base.add(const Duration(hours: 25));
      final r = restaurant(staffList: [
        shotStaff(
          status: 'hurt',
          suppressed: 'afraid',
          emergencyShotAt: base,
          injuryStartedAt: base,
        ),
      ]);
      GameClockService.rollBackEmergencyShots(r, now);
      expect(r.staff.first.status, 'hurt');
    });
  });

  group('automatische Notfall-Spritze nach dem Gefecht', () {
    ProfileData profileWith({required bool withMedic, int budget = 10000}) {
      return ProfileData(
        id: 1,
        name: 'Profil',
        creationDate: base,
        restaurants: [
          RestaurantData(
            id: 1,
            name: 'Restaurant',
            budget: budget,
            staff: [
              StaffData(
                name: 'Held',
                imagePath: 'x.png',
                type: 'apprentice',
                levelValue: 5,
                defenseValue: 100,
                woundValue: 0,
                status: 'dying',
              ),
            ],
            medics: withMedic
                ? [
                    MedicData(
                      id: 1,
                      name: 'Dr. X',
                      quality: 'hoch',
                      costPerWeek: 500,
                      enneagramProfileName: 'Der Chaot',
                    ),
                  ]
                : [],
          ),
        ],
      );
    }

    test('verabreicht `dying` automatisch (Teamarzt + Budget)', () {
      final profile = ObjectProfile();
      profile.loadFromData(profileWith(withMedic: true), restaurantId: 1);
      profile.syncUnitsAfterBattle(const []);
      final c = profile.personal.first;
      expect(c.status, CharacterStatus.ready);
      expect(c.suppressedStatus, CharacterStatus.dying);
      expect(c.emergencyShotAt, isNotNull);
      // Kosten werden gebucht (aktuell 0 €, aber Teil des Vertrags).
      expect(profile.budget, 10000 - EconomyBalance.emergencyShotCost);
    });

    test('ohne Teamarzt keine Spritze', () {
      final profile = ObjectProfile();
      profile.loadFromData(profileWith(withMedic: false), restaurantId: 1);
      profile.syncUnitsAfterBattle(const []);
      final c = profile.personal.first;
      expect(c.status, CharacterStatus.dying);
      expect(c.emergencyShotAt, isNull);
    });
  });
}
