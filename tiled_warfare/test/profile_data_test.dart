import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/cuisine.dart';
import 'package:tiled_warfare/models/match_record.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/models/restaurant_upgrade.dart';

void main() {
  test('RestaurantData serialisiert cuisine/upgrades/lastMatchResult', () {
    final r = RestaurantData(
      id: 7,
      name: 'Test',
      district: 'Harlem',
      cuisine: Cuisine.mexican,
      budget: 1234,
      lastMatchResult: MatchResult.win,
      upgrades: const {UpgradeType.signage: 2, UpgradeType.jukebox: 1},
    );

    final restored = RestaurantData.fromJson(r.toJson());

    expect(restored.id, 7);
    expect(restored.cuisine, Cuisine.mexican);
    expect(restored.budget, 1234);
    expect(restored.lastMatchResult, MatchResult.win);
    expect(restored.upgrades[UpgradeType.signage], 2);
    expect(restored.upgrades[UpgradeType.jukebox], 1);
    expect(restored.upgrades[UpgradeType.tables], isNull);
  });

  test('RestaurantData defaultet Alt-Daten auf italienisch & Stufe 0', () {
    final legacy = RestaurantData.fromJson({
      'id': 1,
      'name': 'Alt',
      'budget': 10000,
    });
    expect(legacy.cuisine, Cuisine.italian);
    expect(legacy.upgrades, isEmpty);
    expect(legacy.lastMatchResult, isNull);
  });

  test('StaffData serialisiert Heilungs-/Spritzenfelder (V3)', () {
    final s = StaffData(
      name: 'Koch',
      imagePath: 'x.png',
      type: 'apprentice',
      status: 'dying',
      injuryStartedAt: DateTime(2026, 1, 1, 12),
      emergencyShotAt: DateTime(2026, 1, 1, 13),
      suppressedStatus: 'dying',
    );

    final restored = StaffData.fromJson(s.toJson());

    expect(restored.status, 'dying');
    expect(restored.injuryStartedAt, DateTime(2026, 1, 1, 12));
    expect(restored.emergencyShotAt, DateTime(2026, 1, 1, 13));
    expect(restored.suppressedStatus, 'dying');
  });

  test('StaffData ohne V3-Felder bleibt abwärtskompatibel', () {
    final restored = StaffData.fromJson({
      'name': 'Alt',
      'imagePath': 'x.png',
      'type': 'apprentice',
      'status': 'ready',
    });
    expect(restored.injuryStartedAt, isNull);
    expect(restored.emergencyShotAt, isNull);
    expect(restored.suppressedStatus, isNull);
  });

  test('StaffData serialisiert ID, Persönlichkeit und Ressourcen (V9)', () {
    final s = StaffData(
      name: 'Koch',
      imagePath: 'x.png',
      type: 'apprentice',
      id: 424242,
      personalityId: 7,
      vitalityCurrent: 42,
      moraleCurrent: 17,
      lastResourceRefillAt: DateTime(2026, 3, 1, 8),
    );

    final restored = StaffData.fromJson(s.toJson());

    expect(restored.id, 424242);
    expect(restored.personalityId, 7);
    expect(restored.vitalityCurrent, 42);
    expect(restored.moraleCurrent, 17);
    expect(restored.lastResourceRefillAt, DateTime(2026, 3, 1, 8));
  });

  test('StaffData defaultet V9-Felder bei Alt-Daten', () {
    final legacy = StaffData.fromJson({
      'name': 'Alt',
      'imagePath': 'x.png',
      'type': 'apprentice',
    });
    expect(legacy.id, -1);
    expect(legacy.personalityId, -1);
    expect(legacy.vitalityCurrent, isNull);
    expect(legacy.moraleCurrent, isNull);
    expect(legacy.lastResourceRefillAt, isNull);
  });

  test('MedicData serialisiert personalityId und liest Alt-Daten (V9)', () {
    final medic = MedicData(
      id: 1,
      name: 'Dr. Test',
      quality: 'hoch',
      costPerWeek: 500,
      enneagramProfileName: 'Der Chaot',
      personalityId: 11,
    );
    final restored = MedicData.fromJson(medic.toJson());
    expect(restored.personalityId, 11);
    expect(restored.enneagramProfileName, 'Der Chaot');

    final legacy = MedicData.fromJson({
      'id': 2,
      'name': 'Dr. Alt',
      'quality': 'niedrig',
      'costPerWeek': 500,
      'enneagramProfileName': 'Der Helfer',
    });
    expect(legacy.personalityId, isNull);
    expect(legacy.enneagramProfileName, 'Der Helfer');
  });

  test(
    'StaffData serialisiert Rang/Station/Rolle und migriert Alt-Daten (V10)',
    () {
      final staff = StaffData(
        name: 'Koch',
        imagePath: 'x.png',
        type: 'apprentice',
        rank: kRankHeadChef,
        station: 'saucier',
        headChefRole: kHeadChefRoleFormal,
        assignedRestaurantId: 42,
      );

      final restored = StaffData.fromJson(staff.toJson());

      expect(restored.rank, kRankHeadChef);
      expect(restored.station, 'saucier');
      expect(restored.headChefRole, kHeadChefRoleFormal);
      expect(restored.assignedRestaurantId, 42);
    },
  );

  test('StaffData leitet den Rang bei Alt-Daten aus dem Typ ab (V10)', () {
    final apprentice = StaffData.fromJson({
      'name': 'Alt',
      'imagePath': 'x.png',
      'type': 'apprentice',
    });
    final lineCook = StaffData.fromJson({
      'name': 'Alt',
      'imagePath': 'x.png',
      'type': 'line_cook',
    });

    expect(apprentice.rank, kRankApprentice);
    expect(apprentice.station, isNull);
    expect(apprentice.headChefRole, isNull);
    expect(apprentice.assignedRestaurantId, isNull);
    expect(lineCook.rank, kRankLineCook);
  });

  test('kProfileSchemaVersion ist 9 (V12: Feature-Mannschaft)', () {
    expect(kProfileSchemaVersion, 9);
  });

  test('RestaurantData.copyWith ersetzt nur staff/budget (V10)', () {
    final original = RestaurantData(
      id: 5,
      name: 'Test',
      district: 'Harlem',
      cuisine: Cuisine.mexican,
      budget: 1000,
      staff: [StaffData(name: 'A', imagePath: 'a.png', type: 'apprentice')],
    );

    final patched = original.copyWith(
      staff: [StaffData(name: 'B', imagePath: 'b.png', type: 'apprentice')],
      budget: 750,
    );

    expect(patched.id, 5);
    expect(patched.name, 'Test');
    expect(patched.district, 'Harlem');
    expect(patched.cuisine, Cuisine.mexican);
    expect(patched.budget, 750);
    expect(patched.staff.single.name, 'B');
    // Original bleibt unberührt.
    expect(original.budget, 1000);
    expect(original.staff.single.name, 'A');
  });
}
