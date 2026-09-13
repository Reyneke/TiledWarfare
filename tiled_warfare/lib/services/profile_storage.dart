import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/services/crash_logger.dart';
import 'package:tiled_warfare/services/district_service.dart';
import 'package:tiled_warfare/utils/crc32.dart';

/// Ein Spielstand, der weder direkt noch aus dem Backup geladen werden konnte.
class ProfileLoadError {
  /// Pfad der betroffenen Datei.
  final String path;

  /// Ursache (der geparste Fehler).
  final Object error;

  const ProfileLoadError(this.path, this.error);

  @override
  String toString() => 'ProfileLoadError($path: $error)';
}

/// Ergebnis eines Ladevorgangs (V6).
///
/// Enthält die erfolgreich geladenen Profile **und** die Dateien, die nicht
/// lesbar waren. Ein defektes Profil legt damit nicht mehr die gesamte Liste
/// lahm; die UI kann einen sichtbaren Fehler anzeigen.
class ProfileLoadResult {
  /// Erfolgreich geladene Profile.
  final List<ProfileData> profiles;

  /// Dateien, die nicht (auch nicht aus dem Backup) geladen werden konnten.
  final List<ProfileLoadError> errors;

  const ProfileLoadResult(this.profiles, this.errors);

  /// `true`, wenn mindestens eine Datei nicht ladbar war.
  bool get hasErrors => errors.isNotEmpty;
}

/// Lokale Speicherverwaltung für Nutzerprofile.
///
/// Jeder Spielstand liegt als `profiles/<id>/profile.json` (alleinige Quelle,
/// V6/L2). Geschrieben wird atomar (`*.tmp` + rename) und mit einer `.bak`-
/// Kopie der letzten guten Version; beim Laden wird bei Bedarf aus dem Backup
/// wiederhergestellt.
///
/// Ein eventuell vorhandener Alt-`index.json` wird beim ersten Laden nach
/// `profiles/<id>/profile.json` migriert und danach entfernt.
class ProfileStorage {
  /// Default-Basisverzeichnis für alle Profile.
  static const String _defaultBaseDirName = 'profiles';

  /// Dateiname eines Spielstands innerhalb des Profilordners.
  static const String _profileFileName = 'profile.json';

  /// Dateiname des Alt-Index (nur noch für die einmalige Migration).
  static const String _legacyIndexFileName = 'index.json';

  /// Endung der Backup-Kopie.
  static const String _backupSuffix = '.bak';

  /// Endung der temporären Datei beim atomaren Schreiben.
  static const String _tempSuffix = '.tmp';

  /// Optionales Überschreiben des Basisverzeichnisses (Tests / Debug).
  static String? baseDirOverride;

  /// Aktuelles Basisverzeichnis (`profiles/`, für Tests überschreibbar).
  static String get baseDirName => baseDirOverride ?? _defaultBaseDirName;

  /// Gibt den Pfad zum Profil-Basisverzeichnis zurück.
  static Directory get _baseDir => Directory(baseDirName);

  /// Datei eines Spielstands (`profiles/<id>/profile.json`).
  static File _profileFile(int id) =>
      File('$baseDirName/$id/$_profileFileName');

  /// Alt-Index (nur für die einmalige Migration).
  static File get _legacyIndexFile =>
      File('$baseDirName/$_legacyIndexFileName');

  /// Initialisiert das Profil-Verzeichnis (erstellt es, falls nicht vorhanden).
  static Future<void> ensureInitialized() async {
    if (!await _baseDir.exists()) {
      await _baseDir.create(recursive: true);
    }
  }

  /// Lädt alle lokal gespeicherten Profile.
  ///
  /// Liest `profiles/<id>/profile.json` per Verzeichnis-Scan (kein Index mehr),
  /// führt die V1/V3-Migration aus und stellt fehlerhafte Dateien bei Bedarf
  /// aus dem `.bak` wieder her. Nicht ladbare Profile landen in
  /// [ProfileLoadResult.errors], die übrigen werden trotzdem zurückgegeben
  /// (statt wie früher eine leere Liste).
  static Future<ProfileLoadResult> loadAllProfiles() async {
    await ensureInitialized();

    final errors = <ProfileLoadError>[];
    await _migrateLegacyIndex(errors);

    final profiles = <ProfileData>[];
    final entries = await _baseDir.list().toList();
    for (final entry in entries) {
      if (entry is! Directory) continue;
      final file = File('${entry.path}/$_profileFileName');
      if (!await file.exists()) continue;
      final profile = await _readProfileFile(file, errors);
      if (profile != null) profiles.add(profile);
    }

    await _migrateProfiles(profiles);
    return ProfileLoadResult(profiles, errors);
  }

  /// Lädt genau einen Spielstand (oder `null`, wenn er nicht existiert).
  static Future<ProfileData?> loadProfile(int id) async {
    final result = await loadAllProfiles();
    for (final profile in result.profiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  /// Speichert ein Profil in seinen eigenen Ordner (atomar, mit Backup).
  static Future<bool> saveProfile(ProfileData profile) async {
    try {
      await _writeProfileData(profile);
      return true;
    } catch (e, stackTrace) {
      CrashLogger.error(
        'Profil konnte nicht gespeichert werden (id=${profile.id})',
        e,
        stackTrace,
      );
      return false;
    }
  }

  /// Schreibt `profiles/<id>/profile.json` atomar. Eine vorhandene Datei wird
  /// vorher als `.bak` gesichert.
  static Future<void> _writeProfileData(ProfileData profile) async {
    await ensureInitialized();
    await _writeAtomically(_profileFile(profile.id), _encode(profile));
  }

  /// Serialisiert [profile] als eingerückten JSON-String.
  static String _encode(ProfileData profile) =>
      const JsonEncoder.withIndent('  ').convert(profile.toJson());

  /// Schreibt [content] atomar nach [target]: erst `*.tmp`, dann `rename`.
  /// Ein Abbruch hinterlässt so nie eine halb geschriebene Spieldatei.
  static Future<void> _writeAtomically(File target, String content) async {
    final dir = target.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final tmp = File('${target.path}$_tempSuffix');
    await tmp.writeAsString(content, flush: true);

    if (await target.exists()) {
      await target.copy('${target.path}$_backupSuffix');
    }
    await tmp.rename(target.path);
  }

  /// Liest eine Spielstand-Datei und fällt bei Fehlern auf `*.bak` zurück.
  ///
  /// Liefert `null` und trägt einen [ProfileLoadError] ein, wenn weder die
  /// Primärdatei noch das Backup gelesen werden konnten.
  static Future<ProfileData?> _readProfileFile(
    File file,
    List<ProfileLoadError> errors,
  ) async {
    final primary = await _tryRead(file);
    if (primary.profile != null) return primary.profile;

    final backup = File('${file.path}$_backupSuffix');
    if (await backup.exists()) {
      final recovered = await _tryRead(backup);
      if (recovered.profile != null) {
        CrashLogger.warn(
          'Profil aus Backup wiederhergestellt: ${file.path} '
          '(Primärdatei: ${primary.error})',
        );
        return recovered.profile;
      }
      errors.add(ProfileLoadError(file.path, primary.error!));
      errors.add(ProfileLoadError(backup.path, recovered.error!));
      return null;
    }

    CrashLogger.error('Profil nicht ladbar: ${file.path}', primary.error);
    errors.add(ProfileLoadError(file.path, primary.error!));
    return null;
  }

  /// Versucht, [file] zu parsen. Wirft nie, sondern liefert den Fehler mit.
  static Future<({ProfileData? profile, Object? error})> _tryRead(
    File file,
  ) async {
    try {
      final content = await file.readAsString();
      final jsonMap = json.decode(content) as Map<String, dynamic>;
      return (profile: ProfileData.fromJson(jsonMap), error: null);
    } catch (e) {
      return (profile: null, error: e);
    }
  }

  /// Migriert einen noch vorhandenen Alt-`index.json` einmalig in die
  /// Einzeldateien und entfernt ihn danach (V6/L2).
  ///
  /// Eine bereits vorhandene `profile.json` wird nicht überschrieben. Fehler-
  /// hafte Alt-Einträge werden geloggt und übersprungen, die übrigen migriert.
  static Future<void> _migrateLegacyIndex(List<ProfileLoadError> errors) async {
    final indexFile = _legacyIndexFile;
    if (!await indexFile.exists()) return;

    try {
      final content = await indexFile.readAsString();
      final List<dynamic> jsonList = json.decode(content) as List<dynamic>;
      for (final entry in jsonList) {
        try {
          final profile = ProfileData.fromJson(entry as Map<String, dynamic>);
          final file = _profileFile(profile.id);
          if (!await file.exists()) {
            await _writeProfileData(profile);
          }
        } catch (e) {
          errors.add(ProfileLoadError(indexFile.path, e));
          CrashLogger.warn('Alt-Eintrag konnte nicht migriert werden', e);
        }
      }
      await indexFile.delete();
      CrashLogger.log('Alt-Index migriert und entfernt: ${indexFile.path}');
    } catch (e) {
      errors.add(ProfileLoadError(indexFile.path, e));
      CrashLogger.error('Alt-Index konnte nicht migriert werden', e);
    }
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

  /// Löscht ein Profil samt Ordner anhand seiner [id].
  static Future<bool> deleteProfile(int id) async {
    await ensureInitialized();

    try {
      final profileDir = Directory('$baseDirName/$id');
      if (await profileDir.exists()) {
        await profileDir.delete(recursive: true);
      }
      return true;
    } catch (e, stackTrace) {
      CrashLogger.error(
        'Profil konnte nicht gelöscht werden (id=$id)',
        e,
        stackTrace,
      );
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
}