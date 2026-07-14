import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/objects/player_objects/object_apprentice.dart';
import 'package:tiled_warfare/objects/player_objects/object_line_cook.dart';
import 'package:tiled_warfare/screens/screen_character_detail.dart';
import 'package:tiled_warfare/screens/screen_hire_and_fire.dart';
import 'package:tiled_warfare/screens/screen_main.dart';
import 'package:tiled_warfare/theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tiled_warfare/l10n/app_localizations.dart';

class MapPreviewEntry {
  final String mapPath;
  final String title;
  final String? previewPath;
  final String tmxPath;

  MapPreviewEntry({
    required this.mapPath,
    required this.title,
    this.previewPath,
    required this.tmxPath,
  });
}

class ScreenRestaurant extends StatefulWidget {
  const ScreenRestaurant({super.key});

  @override
  State<ScreenRestaurant> createState() => _ScreenRestaurantState();
}

class _ScreenRestaurantState extends State<ScreenRestaurant> {
  final ObjectProfile _profile = ObjectProfile();
  String _profileImagePath = 'assets/images/echo_standard.png';
  bool _hasCustomImage = false;
  final Set<ObjectApprentice> _battleReadyCharacters = {};
  List<MapPreviewEntry> _mapEntries = [];
  bool _isLoadingMaps = true;
  String? _mapLoadingError;
  int? _selectedMapIndex;

  @override
  void initState() {
    super.initState();
    if (_profile.restaurantLogoPath != null &&
        _profile.restaurantLogoPath!.isNotEmpty) {
      _profileImagePath = _profile.restaurantLogoPath!;
      _hasCustomImage = true;
    }
    AppTheme.themeModeNotifier.addListener(_onThemeChanged);
    _discoverMaps();
  }

  @override
  void dispose() {
    AppTheme.themeModeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  Future<void> _discoverMaps() async {
    final maps = <MapPreviewEntry>[
      MapPreviewEntry(
        mapPath: 'assets/maps/map0',
        title: 'Street Battle',
        previewPath: null,
        tmxPath: 'assets/maps/map0/street_battle.tmx',
      ),
    ];
    setState(() {
      _mapEntries = maps;
      _isLoadingMaps = false;
    });
  }

  void _toggleTheme() {
    final currentThemeMode = AppTheme.themeModeNotifier.value;
    final ThemeMode next;
    switch (currentThemeMode) {
      case ThemeMode.light:
        next = ThemeMode.dark;
      case ThemeMode.dark:
        next = ThemeMode.system;
      case ThemeMode.system:
        next = ThemeMode.light;
    }
    AppTheme.themeModeNotifier.value = next;
  }

  Future<void> _saveState() async {
    await _profile.saveToStorage();
  }

  Future<void> _showEditRestaurantNameDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: _profile.restaurantName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.renameRestaurant),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.restaurantName,
            hintText: l10n.newNameHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      setState(() {
        _profile.restaurantName = newName;
      });
      await _saveState();
    }
  }

  Future<void> _goToBattle() async {
    _profile.selectTeamForBattle(_battleReadyCharacters.toList());
    final selectedEntry = _selectedMapIndex != null
        ? _mapEntries[_selectedMapIndex!]
        : _mapEntries.first;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScreenMain(mapPath: selectedEntry.tmxPath),
      ),
    );
    setState(() {});
  }

  void _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      try {
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
      } catch (e) {
        debugPrint('Fehler beim Bild-Picking: $e');
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.restaurantLogoError)),
        );
      }
    }
  }

  Widget _buildMapTile(int index, MapPreviewEntry mapEntry, ThemeData theme) {
    final isSelected = _selectedMapIndex == index;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedMapIndex = isSelected ? null : index;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: isSelected
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                )
              : null,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: mapEntry.previewPath != null
                        ? Image.asset(
                            mapEntry.previewPath!,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _buildPlaceholder(theme),
                          )
                        : _buildPlaceholder(theme),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    mapEntry.title,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Icon(
                  isSelected ? Icons.check_circle : Icons.chevron_right,
                  color: isSelected ? theme.colorScheme.primary : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      width: 80,
      height: 80,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.map,
        size: 40,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  /// Gibt eine Farbe basierend auf dem Verletzungsstatus zurück.
  /// Stellt 5 visuelle Stufen dar (statt vorher nur 3), damit der Spieler
  /// ohne Detailansicht den Gesundheitszustand erkennen kann.
  Color _statusAvatarColor(CharacterStatus status) {
    switch (status) {
      case CharacterStatus.ready:
        return Colors.green;
      case CharacterStatus.reeling:
        return Colors.lightGreenAccent;
      case CharacterStatus.hurt:
        return Colors.orange;
      case CharacterStatus.afraid:
      case CharacterStatus.injured:
        return Colors.deepOrange;
      case CharacterStatus.dying:
        return Colors.red;
      case CharacterStatus.dead:
      case CharacterStatus.overkilled:
        return Colors.grey;
    }
  }

  /// Gibt den lokalisierten Text für einen [CharacterStatus] zurück.
  String _statusText(AppLocalizations l10n, CharacterStatus status) {
    switch (status) {
      case CharacterStatus.ready:
        return l10n.statusReady;
      case CharacterStatus.reeling:
        return l10n.statusReeling;
      case CharacterStatus.hurt:
        return l10n.statusHurt;
      case CharacterStatus.afraid:
        return l10n.statusAfraid;
      case CharacterStatus.injured:
        return l10n.statusInjured;
      case CharacterStatus.dying:
        return l10n.statusDying;
      case CharacterStatus.dead:
        return l10n.statusDead;
      case CharacterStatus.overkilled:
        return l10n.statusOverkilled;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(_profile.restaurantName.isNotEmpty
            ? _profile.restaurantName
            : l10n.restaurant),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: l10n.renameRestaurant,
            onPressed: () => _showEditRestaurantNameDialog(context),
          ),
          IconButton(
            icon: Icon(
              switch (AppTheme.themeModeNotifier.value) {
                ThemeMode.light => Icons.light_mode,
                ThemeMode.dark => Icons.dark_mode,
                ThemeMode.system => Icons.settings_brightness,
              },
            ),
            tooltip: l10n.themeToggle(AppTheme.themeModeNotifier.value.name),
            onPressed: _toggleTheme,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                        tooltip: l10n.changeProfileImage,
                        onPressed: _pickImage,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.person, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _profile.name.isNotEmpty ? _profile.name : l10n.player,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.group_add),
                  tooltip: l10n.managePersonnel,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ScreenHireAndFire()),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Icon(Icons.account_balance_wallet,
                    color: theme.colorScheme.secondary),
                const SizedBox(width: 8),
                Text(
                  l10n.budgetLabel(_profile.budget),
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
            Text(
              l10n.personnelCount(_profile.personalCount),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            if (_profile.personal.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      l10n.noPersonnelYet,
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
                  final hasMedic = _profile.hiredMedics.isNotEmpty;
                  final needsTreat = character.status != CharacterStatus.ready;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ScreenCharacterDetail(
                                character: character),
                          ),
                        );
                      },
                      leading: CircleAvatar(
                        backgroundColor: _statusAvatarColor(character.status),
                        child: Icon(
                          character is ObjectLineCook
                              ? Icons.restaurant
                              : Icons.school,
                          color: character.status == CharacterStatus.dying
                              ? Colors.white
                              : null,
                        ),
                      ),
                      title: Text(
                        '${character.name} (${l10n.level(character.levelValue)})',
                      ),
                      subtitle: Text(
                        [
                          '❤️ ${character.woundValue}',
                          _statusText(l10n, character.status),
                          '⚔️ ${character.attackValue}',
                          '🛡️ ${character.defenseValue}',
                          '🏃 ${character.movementValue}',
                          if (character is ObjectLineCook)
                            '🎯 ${character.rangeValue}',
                        ].join(' · '),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasMedic && needsTreat)
                            IconButton(
                              icon: const Icon(Icons.healing,
                                  color: Colors.green),
                              tooltip: l10n.medicAssignTooltip,
                              onPressed: () {
                                final medic =
                                    _profile.hiredMedics.first;
                                if (medic.treatCharacter(character)) {
                                  setState(() {});
                                  _saveState();
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      SnackBar(
                                        content: Text(l10n.treatmentSuccess(character.name)),
                                      ),
                                    );
                                } else {
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      SnackBar(
                                        content: Text(l10n.treatmentFailed),
                                      ),
                                    );
                                }
                              },
                            ),
                          if (hasMedic &&
                              (character.woundValue <= 0 ||
                               character.status == CharacterStatus.dying))
                            IconButton(
                              icon: const Icon(Icons.emergency,
                                  color: Colors.red),
                              tooltip: l10n.emergencyShot,
                              onPressed: () {
                                final medic =
                                    _profile.hiredMedics.first;
                                if (medic.emergencyShot(character)) {
                                  setState(() {});
                                  _saveState();
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      SnackBar(
                                        content: Text(l10n.emergencyShotSuccess(character.name)),
                                      ),
                                    );
                                } else {
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      SnackBar(
                                        content: Text(l10n.emergencyShotFailed),
                                      ),
                                    );
                                }
                              },
                            ),
                          Checkbox(
                            value: isReady,
                            onChanged: canFight
                                ? (value) {
                                    setState(() {
                                      if (value == true) {
                                        _battleReadyCharacters
                                            .add(character);
                                      } else {
                                        _battleReadyCharacters
                                            .remove(character);
                                      }
                                    });
                                  }
                                : null,
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.person_add),
              label: Text(l10n.hireNewPersonnel),
              onPressed: () {
                final success = _profile.hireApprentice();
                if (!success) {
                  final l10n = AppLocalizations.of(context)!;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.notEnoughBudget)),
                  );
                }
                setState(() {});
                _saveState();
              },
            ),
            const SizedBox(height: 8),
            Text(
              l10n.availableMaps,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            if (_isLoadingMaps)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_mapLoadingError != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    l10n.mapLoadError(_mapLoadingError!),
                    style: TextStyle(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (_mapEntries.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      l10n.noMapsFound,
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
                itemCount: _mapEntries.length,
                itemBuilder: (context, index) {
                  return _buildMapTile(index, _mapEntries[index], theme);
                },
              ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.play_arrow),
              label: Text(l10n.startBattle),
              onPressed:
                  _battleReadyCharacters.isNotEmpty && _mapEntries.isNotEmpty
                      ? _goToBattle
                      : null,
            ),
          ],
        ),
      ),
    );
  }
}