import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tiled_warfare/objects/object_player.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/objects/player_objects/object_appretice.dart';
import 'package:tiled_warfare/objects/player_objects/object_line_cook.dart';
import 'package:tiled_warfare/screens/screen_main.dart';
import 'package:tiled_warfare/theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';

/// Bildschirm zur Verwaltung des Restaurants und des Teams.
///
/// Zeigt den Restaurant-Namen, ein Profilbild (austauschbar via ImagePicker),
/// den Spieler-Namen, das Budget sowie eine Liste aller angestellten Charaktere
/// in Cards. Über eine Checkbox kann jeder Charakter als "gefechtsbereit"
/// markiert werden. Ein Button wechselt zum [ScreenMain] und übergibt die
/// ausgewählten, gefechtsbereiten Einheiten an [ObjectPlayer].
///
/// Alle Änderungen (Personal anheuern/entlassen, Budget, Profilbild) werden
/// automatisch mittels [ObjectProfile.saveToStorage] persistiert.
class ScreenRestaurant extends StatefulWidget {
  const ScreenRestaurant({super.key});

  @override
  State<ScreenRestaurant> createState() => _ScreenRestaurantState();
}

class _ScreenRestaurantState extends State<ScreenRestaurant> {
  // ── Abhängigkeiten (Singletons) ──────────────────────────────────────
  final ObjectProfile _profile = ObjectProfile();

  // ── Lokaler Zustand ──────────────────────────────────────────────────
  /// Pfad zum aktuellen Profilbild.
  String _profileImagePath = 'assets/images/echo_standard.png';

  /// Ob ein benutzerdefiniertes Bild aus der Galerie geladen wurde.
  bool _hasCustomImage = false;

  /// Aktuelles Theme-Mode für die AppBar-Umschaltung.
  ThemeMode _themeMode = ThemeMode.system;

  /// Menge der Charaktere, die als "gefechtsbereit" markiert sind.
  final Set<ObjectApprentice> _battleReadyCharacters = {};

  // ── Lifecycle ────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    // Restaurant-Logo aus dem persistierten ObjectProfile-Singleton laden.
    // Das Logo wird in [ObjectProfile.restaurantLogoPath] gehalten und
    // über [RestaurantData.logoPath] in der ProfileData gespeichert.
    if (_profile.restaurantLogoPath != null &&
        _profile.restaurantLogoPath!.isNotEmpty) {
      _profileImagePath = _profile.restaurantLogoPath!;
      _hasCustomImage = true;
    }

    _themeMode = AppTheme.themeModeNotifier.value;
    AppTheme.themeModeNotifier.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    AppTheme.themeModeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {
      _themeMode = AppTheme.themeModeNotifier.value;
    });
  }

  // ── Hilfsmethoden ────────────────────────────────────────────────────
  void _toggleTheme() {
    final ThemeMode next;
    switch (_themeMode) {
      case ThemeMode.light:
        next = ThemeMode.dark;
      case ThemeMode.dark:
        next = ThemeMode.system;
      case ThemeMode.system:
        next = ThemeMode.light;
    }
    AppTheme.themeModeNotifier.value = next;
  }

  /// Speichert den aktuellen Zustand des ObjectProfile asynchron.
  Future<void> _saveState() async {
    await _profile.saveToStorage();
  }

  /// Wechselt zum Haupt-Spielbildschirm und übergibt die gefechtsbereiten
  /// Einheiten an [ObjectPlayer].
  void _goToBattle() {
    _profile.selectTeamForBattle(_battleReadyCharacters.toList());
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ScreenMain()));
  }

  void _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      try {
        // Restaurant-Logo in den Profil-Ordner kopieren, damit es nach einem
        // App-Neustart noch verfügbar ist (der temporäre Galerie-Pfad würde
        // sonst verloren gehen).
        final profileDir = Directory('profiles/${_profile.id}');
        if (!await profileDir.exists()) {
          await profileDir.create(recursive: true);
        }

        final imageExtension = image.name.contains('.')
            ? '.${image.name.split('.').last}'
            : '.png';
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final destPath = '${profileDir.path}/restaurant_$timestamp$imageExtension';
        final destFile = File(destPath);

        // Alte Restaurant-Logos bereinigen
        if (await profileDir.exists()) {
          final oldLogos = await profileDir
              .list()
              .where((entity) =>
                  entity is File && entity.path.contains('restaurant_'))
              .toList();
          for (final old in oldLogos) {
            await (old as File).delete();
          }
        }

        await destFile.writeAsBytes(await image.readAsBytes());

        setState(() {
          _profileImagePath = destPath;
          _hasCustomImage = true;
          _profile.restaurantLogoPath = destPath;
        });
        _saveState();
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fehler beim Laden des Restaurantlogos.'),
          ),
        );
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_profile.restaurantName.isNotEmpty
            ? _profile.restaurantName
            : 'Restaurant'),
        actions: [
          IconButton(
            icon: Icon(
              switch (_themeMode) {
                ThemeMode.light => Icons.light_mode,
                ThemeMode.dark => Icons.dark_mode,
                ThemeMode.system => Icons.settings_brightness,
              },
            ),
            tooltip: 'Theme wechseln (${_themeMode.name})',
            onPressed: _toggleTheme,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Profilbild ──────────────────────────────────────────
            Center(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _hasCustomImage
                        ? Image.file(
                            File(_profileImagePath),
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 200,
                              height: 200,
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.broken_image, size: 64),
                            ),
                          )
                        : Image.asset(
                            _profileImagePath,
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 200,
                              height: 200,
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.broken_image, size: 64),
                            ),
                          ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.white),
                        tooltip: 'Profilbild ändern',
                        onPressed: _pickImage,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Name & Budget ────────────────────────────────────────
            Row(
              children: [
                Icon(Icons.person, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _profile.name.isNotEmpty ? _profile.name : 'Spieler',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.account_balance_wallet,
                    color: theme.colorScheme.secondary),
                const SizedBox(width: 8),
                Text(
                  '${_profile.budget} €',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _profile.budget < 0
                        ? theme.colorScheme.error
                        : null,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Personal-Liste ──────────────────────────────────────
            Text(
              'Personal (${_profile.personalCount})',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),

            if (_profile.personal.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      'Noch kein Personal eingestellt.\nHeuere einen Lehrling an!',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _profile.personal.length,
                itemBuilder: (context, index) {
                  final character = _profile.personal[index];
                  final isReady = _battleReadyCharacters.contains(character);
                  final bool canFight =
                      character.status != CharacterStatus.dying;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: canFight
                            ? (isReady
                                ? Colors.green
                                : theme.colorScheme.surfaceContainerHighest)
                            : theme.colorScheme.error,
                        child: Icon(
                          character is ObjectLineCook
                              ? Icons.restaurant
                              : Icons.school,
                          color: canFight ? null : Colors.white,
                        ),
                      ),
                      title: Text(
                        '${character.name} (Level ${character.levelValue})',
                      ),
                      subtitle: Text(
                        [
                          '❤️ ${character.woundValue}',
                          '⚔️ ${character.attackValue}',
                          '🛡️ ${character.defenseValue}',
                          '🏃 ${character.movementValue}',
                          if (character is ObjectLineCook)
                            '🎯 ${character.rangeValue}',
                          if (!canFight) '💀 Ausgefallen',
                        ].join(' · '),
                      ),
                      trailing: Checkbox(
                        value: isReady,
                        onChanged: canFight
                            ? (value) {
                                setState(() {
                                  if (value == true) {
                                    _battleReadyCharacters.add(character);
                                  } else {
                                    _battleReadyCharacters.remove(character);
                                  }
                                });
                              }
                            : null,
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),

            const SizedBox(height: 16),

            // ── Aktionen ──────────────────────────────────────────────
            FilledButton.icon(
              icon: const Icon(Icons.person_add),
              label: const Text('Neues Personal anheuern'),
              onPressed: () {
                final success = _profile.hireApprentice();
                if (!success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Budget reicht nicht zum Anheuern!'),
                    ),
                  );
                }
                setState(() {});
                _saveState();
              },
            ),

            const SizedBox(height: 8),

            FilledButton.tonalIcon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Gefecht starten'),
              onPressed:
                  _battleReadyCharacters.isNotEmpty ? _goToBattle : null,
            ),
          ],
        ),
      ),
    );
  }
}