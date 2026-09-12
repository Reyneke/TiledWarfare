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
}
