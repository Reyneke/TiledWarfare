import 'dart:convert';
import 'dart:io';

import 'package:tiled_warfare/models/profile_data.dart';
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
  static Future<List<ProfileData>> loadAllProfiles() async {
    await ensureInitialized();

    if (!await _indexFile.exists()) {
      return [];
    }

    try {
      final content = await _indexFile.readAsString();
      final List<dynamic> jsonList = json.decode(content) as List<dynamic>;
      return jsonList
          .map((e) => ProfileData.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Speichert ein Profil sowohl im Index als auch im eigenen Ordner.
  static Future<bool> saveProfile(ProfileData profile) async {
    await ensureInitialized();

    try {
      // 1. Profil-Ordner erstellen
      final profileDir = Directory('$_baseDirName/${profile.id}');
      if (!await profileDir.exists()) {
        await profileDir.create(recursive: true);
      }

      // 2. Profildaten im eigenen Ordner speichern
      final profileFile = File('${profileDir.path}/profile.json');
      await profileFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(profile.toJson()),
      );

      // 3. Index aktualisieren
      final allProfiles = await loadAllProfiles();
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

      return true;
    } catch (e) {
      return false;
    }
  }

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