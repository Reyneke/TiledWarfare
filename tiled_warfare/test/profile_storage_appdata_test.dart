import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/services/profile_storage.dart';

/// Plattform-Doppel für `path_provider` (P6, 4.2/#4): liefert ein temporäres
/// Verzeichnis als „AppData“-Ordner, damit der Umzug testbar ist.
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationSupportPath() async => root;
}

/// Tests für den plattformgerechten Speicherort der Spielstände (P6/`6` L6):
/// AppData-Auflösung, einmalige tolerante Migration aus dem relativen
/// `profiles/`-Ordner und die Auflösung von Legacy-Bildpfaden.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;
  late Directory legacyCwd;
  late Directory appData;
  late String originalCwd;

  setUpAll(() async {
    sandbox = await Directory.systemTemp.createTemp('tw_appdata_test_');
    appData = Directory('${sandbox.path}/support');
    // Der Test spielt im „Arbeitsverzeichnis“ der App: dort liegt der alte
    // relative `profiles/`-Ordner, den die Migration vorfinden soll.
    legacyCwd = Directory('${sandbox.path}/cwd');
    await legacyCwd.create(recursive: true);
    originalCwd = Directory.current.path;
    Directory.current = legacyCwd.path;
    PathProviderPlatform.instance = _FakePathProvider(appData.path);
  });

  tearDownAll(() async {
    Directory.current = originalCwd;
    if (await sandbox.exists()) {
      await sandbox.delete(recursive: true);
    }
  });

  /// Legt einen Spielstand im **alten** relativen Ordner ab – so, wie ihn eine
  /// Vor-P6-Installation hinterlassen hätte (inkl. relativem Logo-Pfad).
  Future<void> seedLegacySavegame() async {
    final dir = Directory('${legacyCwd.path}/profiles/7');
    await dir.create(recursive: true);
    await File('${dir.path}/logo.png').writeAsBytes(const [1, 2, 3]);
    final profile = ProfileData(
      id: 7,
      name: 'Umzug',
      creationDate: DateTime(2026, 1, 1),
      restaurants: [
        RestaurantData(
          id: 70,
          name: 'Alt-Restaurant',
          budget: 1234,
          logoPath: 'profiles/7/logo.png',
        ),
      ],
    );
    await File('${dir.path}/profile.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(profile.toJson()),
    );
  }

  test('löst den Spielstand-Ordner aus AppData auf und migriert Altbestände',
      () async {
    await seedLegacySavegame();
    final legacyFile = File('${legacyCwd.path}/profiles/7/profile.json');
    expect(await legacyFile.exists(), isTrue);

    final result = await ProfileStorage.loadAllProfiles();

    // 1) Der Ordner liegt jetzt im AppData-Unterordner …
    expect(ProfileStorage.usesAppDataDir, isTrue);
    expect(
      ProfileStorage.baseDirName,
      '${appData.path}${Platform.pathSeparator}tiled_warfare_profiles',
    );

    // 2) … die Altbestände wurden kopiert (nicht verschoben) …
    expect(await legacyFile.exists(), isTrue);
    expect(result.hasErrors, isFalse);
    expect(result.profiles.single.id, 7);
    expect(result.profiles.single.restaurants.single.name, 'Alt-Restaurant');

    // 3) … und das Bild der Kopie ist weiterhin erreichbar.
    final migratedLogo = File(
      '${ProfileStorage.baseDirName}${Platform.pathSeparator}7'
      '${Platform.pathSeparator}logo.png',
    );
    expect(await migratedLogo.exists(), isTrue);
    expect(
      ProfileStorage.absolutePath('profiles/7/logo.png'),
      migratedLogo.absolute.path,
    );
  });

  test('absolutePath lässt unbekannte Pfade unverändert', () {
    expect(
      ProfileStorage.absolutePath('profiles/999/fehlt.png'),
      'profiles/999/fehlt.png',
    );
    expect(ProfileStorage.absolutePath(''), '');
  });
}
