import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/cuisine.dart';
import 'package:tiled_warfare/models/match_record.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/models/restaurant_upgrade.dart';
import 'package:tiled_warfare/services/profile_storage.dart';

/// V6-Tests für die gehärtete Persistenz: eine Quelle der Wahrheit,
/// atomare Schreibvorgänge, Backup-Recovery und sichtbare Fehler.
void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('tw_storage_test_');
    ProfileStorage.baseDirOverride = temp.path;
  });

  tearDown(() async {
    ProfileStorage.baseDirOverride = null;
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  File profileFile(int id) => File('${temp.path}/$id/profile.json');

  ProfileData buildProfile({required int id, required String name}) =>
      ProfileData(
        id: id,
        name: name,
        creationDate: DateTime(2026, 1, 1),
        restaurants: [
          RestaurantData(
            id: id * 10,
            name: '$name-Restaurant',
            district: 'Harlem',
            cuisine: Cuisine.mexican,
            budget: 1234,
            lastSeenAt: DateTime(2026, 1, 2),
            lastMatchResult: MatchResult.win,
            upgrades: const {UpgradeType.signage: 2},
            staff: [
              StaffData(
                name: 'Koch',
                imagePath: 'x.png',
                type: 'apprentice',
                status: 'dying',
                injuryStartedAt: DateTime(2026, 1, 1, 12),
              ),
            ],
            medics: [
              MedicData(
                id: 1,
                name: 'Rossi',
                quality: 'mittel',
                costPerWeek: 1000,
                enneagramProfileName: 'Der Chaot',
              ),
            ],
          ),
        ],
      );

  test('Save/Load-Roundtrip erhält Spielstand, Personal & Erweiterungen',
      () async {
    final profile = buildProfile(id: 1, name: 'Testprofil');
    expect(await ProfileStorage.saveProfile(profile), isTrue);

    final result = await ProfileStorage.loadAllProfiles();
    expect(result.hasErrors, isFalse);
    expect(result.profiles, hasLength(1));

    final loaded = result.profiles.single;
    expect(loaded.id, 1);
    expect(loaded.restaurants, hasLength(1));

    final r = loaded.restaurants.single;
    expect(r.id, 10);
    expect(r.cuisine, Cuisine.mexican);
    expect(r.budget, 1234);
    expect(r.lastMatchResult, MatchResult.win);
    expect(r.upgrades[UpgradeType.signage], 2);
    expect(r.staff.single.status, 'dying');
    expect(r.staff.single.injuryStartedAt, DateTime(2026, 1, 1, 12));
    expect(r.medics.single.name, 'Rossi');
  });

  test('serialisiert das Schema-Version-Feld', () {
    final json = buildProfile(id: 1, name: 'P').toJson();
    expect(json['version'], kProfileSchemaVersion);
  });

  test('korrupte Datei liefert Fehler, die übrigen Profile laden weiter',
      () async {
    await ProfileStorage.saveProfile(buildProfile(id: 1, name: 'A'));
    await ProfileStorage.saveProfile(buildProfile(id: 2, name: 'B'));
    await profileFile(2).writeAsString('{ kaputt');

    final result = await ProfileStorage.loadAllProfiles();
    expect(result.hasErrors, isTrue);
    expect(result.errors.single.path, endsWith('profile.json'));
    expect(result.profiles.map((p) => p.id), contains(1));
    expect(result.profiles.map((p) => p.id), isNot(contains(2)));
  });

  test('stellt einen beschädigten Spielstand aus dem Backup wieder her',
      () async {
    final profile = buildProfile(id: 3, name: 'Backup');
    await ProfileStorage.saveProfile(profile); // erzeugt profile.json
    await ProfileStorage.saveProfile(profile); // erzeugt profile.json.bak
    await profileFile(3).writeAsString('{ kaputt');

    final result = await ProfileStorage.loadAllProfiles();
    expect(result.hasErrors, isFalse);
    expect(
      result.profiles.single.restaurants.single.name,
      'Backup-Restaurant',
    );
  });

  test('atomares Schreiben hinterlässt keine .tmp-Datei', () async {
    await ProfileStorage.saveProfile(buildProfile(id: 4, name: 'Atomic'));
    expect(await File('${temp.path}/4/profile.json.tmp').exists(), isFalse);
  });

  test('zwei gleichzeitige Saves verlieren keinen Spielstand', () async {
    await Future.wait([
      ProfileStorage.saveProfile(buildProfile(id: 5, name: 'A')),
      ProfileStorage.saveProfile(buildProfile(id: 6, name: 'B')),
    ]);

    final result = await ProfileStorage.loadAllProfiles();
    expect(result.profiles.map((p) => p.id).toSet(), {5, 6});
  });

  test('saveProfile meldet einen nicht beschreibbaren Pfad als false',
      () async {
    final blocker = File('${temp.path}/blocker');
    await blocker.writeAsString('kein Verzeichnis');
    ProfileStorage.baseDirOverride = blocker.path;

    expect(
      await ProfileStorage.saveProfile(buildProfile(id: 7, name: 'X')),
      isFalse,
    );
  });

  test('migriert einen Alt-index.json in Einzeldateien und entfernt ihn',
      () async {
    final indexFile = File('${temp.path}/index.json');
    await indexFile.writeAsString(
      jsonEncode([buildProfile(id: 8, name: 'Legacy').toJson()]),
    );

    final result = await ProfileStorage.loadAllProfiles();
    expect(result.profiles.single.id, 8);
    expect(await profileFile(8).exists(), isTrue);
    expect(await indexFile.exists(), isFalse);
  });

  test('fromJson bleibt bei defekten Feldern tolerant', () {
    final legacy = ProfileData.fromJson({
      'id': 9,
      'name': 'Alt',
      'creationDate': '2026-01-01T00:00:00.000',
      'restaurants': [
        {'id': 1, 'name': 'Alt-Restaurant', 'budget': 10000},
        {'kaputt': true},
      ],
    });
    expect(legacy.id, 9);
    expect(legacy.restaurants, hasLength(2));
    expect(legacy.restaurants.first.cuisine, Cuisine.italian);

    final broken = ProfileData.fromJson({
      'id': 'keine-zahl',
      'creationDate': 'kein-datum',
      'restaurants': 'keine-liste',
    });
    expect(broken.id, -1);
    expect(broken.restaurants, isEmpty);
  });
}
