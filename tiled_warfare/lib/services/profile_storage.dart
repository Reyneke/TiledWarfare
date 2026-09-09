import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/services/district_service.dart';
import 'package:tiled_warfare/utils/crc32.dart';

/// Lokale Speicherverwaltung für Nutzerprofile.
///
/// Alle Profile werden als JSON-Dateien in einem zentralen Ordner
/// (`profiles/`) abgelegt. Jedes Profil bekommt einen eigenen Unterordner,
/// dessen Name der Profil-ID entspricht (z. B. `profiles/<id>/`).
///
/// Die Profil-Liste wird in `profiles/index.json` geführt.
class ProfileStorage {
  /// Basis-Verzeichnis für alle Profile.
  static const String _baseDirName = 'profiles';

  /// Name der Index-Datei.
  static const String _indexFileName = 'index.json';

  /// Gibt den Pfad zum Profil-Basisverzeichnis zurück.
  static Directory get _baseDir => Directory(_baseDirName);

  /// Gibt den Pfad zur Index-Datei zurück.
  static File get _indexFile => File('$_baseDirName/$_indexFileName');

  /// Initialisiert das Profil-Verzeichnis (erstellt es, falls nicht vorhanden).
  static Future<void> ensureInitialized() async {
    if (!await _baseDir.exists()) {
      await _baseDir.create(recursive: true);
    }
  }

  /// Gibt eine Liste aller lokal gespeicherten Profile zurück.
  ///
  /// Lädt die `index.json` und deserialisiert die enthaltenen Profile.
  /// Sollte die Datei nicht existieren oder beschädigt sein, wird eine
  /// leere Liste zurückgegeben.
  static Future<List<ProfileData>> loadAllProfiles() =>
      _loadAllProfiles(migrate: true);

  /// Internal loader without migration (used by [_writeProfileData] to update
  /// the index without recursion into [loadAllProfiles]).
  static Future<List<ProfileData>> _loadAllProfiles({
    required bool migrate,
  }) async {
    await ensureInitialized();

    if (!await _indexFile.exists()) {
      return [];
    }

    try {
      final content = await _indexFile.readAsString();
      final List<dynamic> jsonList = json.decode(content) as List<dynamic>;
      final profiles = jsonList
          .map((e) => ProfileData.fromJson(e as Map<String, dynamic>))
          .toList();
      if (migrate) {
        await _migrateProfiles(profiles);
      }
      return profiles;
    } catch (e) {
      return [];
    }
  }

  /// Speichert ein Profil sowohl im Index als auch im eigenen Ordner.
  static Future<bool> saveProfile(ProfileData profile) async {
    try {
      await _writeProfileData(profile);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Writes a profile to its own folder and updates the index.
  ///
  /// Uses [_loadAllProfiles] with `migrate: false` internally so the migration
  /// in [loadAllProfiles] is not triggered recursively.
  static Future<void> _writeProfileData(ProfileData profile) async {
    await ensureInitialized();

    // 1. Create the profile folder.
    final profileDir = Directory('$_baseDirName/${profile.id}');
    if (!await profileDir.exists()) {
      await profileDir.create(recursive: true);
    }

    // 2. Store the profile data in its own folder.
    final profileFile = File('${profileDir.path}/profile.json');
    await profileFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(profile.toJson()),
    );

    // 3. Update the index.
    final allProfiles = await _loadAllProfiles(migrate: false);
    final existingIndex = allProfiles.indexWhere((p) => p.id == profile.id);
    if (existingIndex >= 0) {
      allProfiles[existingIndex] = profile;
    } else {
      allProfiles.add(profile);
    }
    await _indexFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        allProfiles.map((p) => p.toJson()).toList(),
      ),
    );
  }

  /// Migrates legacy profiles once (V1).
  ///
  /// Lifts legacy profile-level state onto the first savegame, assigns
  /// deterministic ids (CRC32) and `lastSeenAt`, and randomly assigns free
  /// districts to restaurants without one. Changed profiles are persisted
  /// immediately.
  static Future<void> _migrateProfiles(List<ProfileData> profiles) async {
    List<String> districtNames = const [];
    try {
      districtNames = (await DistrictService.loadDistricts())
          .map((d) => d.name)
          .toList();
    } catch (_) {
      // World map unavailable -> no district assignment possible.
    }

    final migrated = <ProfileData>[];
    for (final profile in profiles) {
      if (_migrateProfile(profile, districtNames)) {
        migrated.add(profile);
      }
    }

    for (final profile in migrated) {
      await _writeProfileData(profile);
    }
  }

  /// Runs the one-time migration for a single [profile]. Returns `true` if
  /// anything changed (and should therefore be persisted).
  static bool _migrateProfile(ProfileData profile, List<String> districtNames) {
    var changed = false;
    final seed = profile.creationDate.toIso8601String();

    // Legacy state on profile level -> lift onto the first savegame.
    final bool hasProfileState = profile.staff.isNotEmpty ||
        profile.medics.isNotEmpty ||
        profile.budget != kDefaultRestaurantBudget;

    if (profile.restaurants.isEmpty) {
      // Only fabricate a default savegame if there is profile-level state to
      // preserve. A brand-new, empty profile stays empty so the player can
      // found a restaurant in a district of their choice.
      if (hasProfileState) {
        final staff = List<StaffData>.from(profile.staff);
        final medics = List<MedicData>.from(profile.medics);
        profile.restaurants.add(RestaurantData(
          name: 'Neues Restaurant',
          budget: profile.budget,
          staff: staff,
          medics: medics,
        ));
        profile.staff.clear();
        profile.medics.clear();
        profile.budget = kDefaultRestaurantBudget;
        changed = true;
      }
    } else if (hasProfileState &&
        !_restaurantHasState(profile.restaurants.first)) {
      final first = profile.restaurants.first;
      first.budget = profile.budget;
      first.staff = List<StaffData>.from(profile.staff);
      first.medics = List<MedicData>.from(profile.medics);
      profile.staff.clear();
      profile.medics.clear();
      profile.budget = kDefaultRestaurantBudget;
      changed = true;
    }

    // Deterministic ids + lastSeenAt for every restaurant.
    for (var i = 0; i < profile.restaurants.length; i++) {
      final r = profile.restaurants[i];
      if (r.id <= 0) {
        r.id = CRC32.compute('${r.name}$seed#$i');
        changed = true;
      }
      if (r.lastSeenAt == null) {
        r.lastSeenAt = DateTime.now();
        changed = true;
      }
    }

    // Random assignment of missing districts onto free districts.
    final used = <String>{
      for (final r in profile.restaurants)
        if (r.district != null && r.district!.isNotEmpty) r.district!,
    };
    final free = districtNames.where((d) => !used.contains(d)).toList();
    final random = Random();
    for (final r in profile.restaurants) {
      final needsDistrict = r.district == null ||
          r.district!.isEmpty ||
          !districtNames.contains(r.district!);
      if (!needsDistrict) continue;
      if (free.isEmpty) break; // no free district left
      final index = random.nextInt(free.length);
      r.district = free.removeAt(index);
      changed = true;
    }

    return changed;
  }

  /// Returns `true` if [r] already carries any per-restaurant state.
  static bool _restaurantHasState(RestaurantData r) =>
      r.staff.isNotEmpty ||
      r.medics.isNotEmpty ||
      r.budget != kDefaultRestaurantBudget;

  /// Löscht ein Profil (samt Ordner) anhand seiner [id].
  static Future<bool> deleteProfile(int id) async {
    await ensureInitialized();

    try {
      // 1. Profil-Ordner rekursiv löschen
      final profileDir = Directory('$_baseDirName/$id');
      if (await profileDir.exists()) {
        await profileDir.delete(recursive: true);
      }

      // 2. Aus dem Index entfernen
      final allProfiles = await loadAllProfiles();
      allProfiles.removeWhere((p) => p.id == id);
      await _indexFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(
          allProfiles.map((p) => p.toJson()).toList(),
        ),
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Erzeugt ein neues Profil mit einem CRC32-Hash als ID.
  ///
  /// Die ID wird berechnet aus: `crc32(name + creationDate.toIso8601String())`.
  static ProfileData createProfile(String name) {
    final now = DateTime.now();
    final hashInput = '$name${now.toIso8601String()}';
    final id = CRC32.compute(hashInput);
    return ProfileData(
      id: id,
      name: name,
      creationDate: now,
    );
  }

  /// Fügt einem bestehenden Profil ein Restaurant hinzu und speichert es.
  static Future<bool> addRestaurantToProfile(
    int profileId,
    RestaurantData restaurant,
  ) async {
    final profiles = await loadAllProfiles();
    final index = profiles.indexWhere((p) => p.id == profileId);
    if (index < 0) return false;

    profiles[index].restaurants.add(restaurant);
    return saveProfile(profiles[index]);
  }

  /// Entfernt ein Restaurant aus einem Profil.
  static Future<bool> removeRestaurantFromProfile(
    int profileId,
    int restaurantIndex,
  ) async {
    final profiles = await loadAllProfiles();
    final index = profiles.indexWhere((p) => p.id == profileId);
    if (index < 0) return false;
    if (restaurantIndex < 0 ||
        restaurantIndex >= profiles[index].restaurants.length) {
      return false;
    }

    profiles[index].restaurants.removeAt(restaurantIndex);
    return saveProfile(profiles[index]);
  }
}