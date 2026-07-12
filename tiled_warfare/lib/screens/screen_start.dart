import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tiled_warfare/main_app.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/services/profile_storage.dart';
import 'package:tiled_warfare/screens/screen_restaurant.dart';
import 'package:tiled_warfare/theme/app_theme.dart';
import 'package:tiled_warfare/l10n/app_localizations.dart';

/// Start-Bildschirm zur Verwaltung lokaler Nutzerdaten.
class ScreenStart extends StatefulWidget {
  final LocaleProvider localeProvider;
  const ScreenStart({super.key, required this.localeProvider});

  @override
  State<ScreenStart> createState() => _ScreenStartState();
}

class _ScreenStartState extends State<ScreenStart> {
  List<ProfileData> _profiles = [];
  ProfileData? _selectedProfile;
  RestaurantData? _selectedRestaurant;
  bool _isLoading = true;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    AppTheme.themeModeNotifier.addListener(_onThemeChanged);
    _loadProfiles();
  }

  @override
  void dispose() {
    AppTheme.themeModeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  Future<void> _loadProfiles() async {
    final profiles = await ProfileStorage.loadAllProfiles();
    setState(() {
      _profiles = profiles;
      if (_selectedProfile != null &&
          !profiles.any((p) => p.id == _selectedProfile!.id)) {
        _selectedProfile = null;
        _selectedRestaurant = null;
      }
      _isLoading = false;
    });
  }

  ProfileData? _findProfileById(int id) {
    for (final p in _profiles) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<String?> _showTextFormDialog({
    required String title,
    required String labelText,
    required String hintText,
    required String confirmText,
    String? initialValue,
  }) async {
    final nameController = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();
    final l10n = AppLocalizations.of(context)!;

    try {
      return await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: labelText,
                hintText: hintText,
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.pleaseEnterName;
                }
                return null;
              },
              autofocus: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  Navigator.pop(context, nameController.text.trim());
                }
              },
              child: Text(confirmText),
            ),
          ],
        ),
      );
    } finally {
      nameController.dispose();
    }
  }

  Future<void> _showCreateProfileDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await _showTextFormDialog(
      title: l10n.newProfile,
      labelText: l10n.profileName,
      hintText: l10n.playerNameHint,
      confirmText: l10n.create,
    );

    if (result != null && result.isNotEmpty) {
      final newProfile = ProfileStorage.createProfile(result);
      await ProfileStorage.saveProfile(newProfile);
      await _loadProfiles();
    }
  }

  Future<void> _showRenameProfileDialog(ProfileData profile) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await _showTextFormDialog(
      title: l10n.renameProfile,
      labelText: l10n.profileName,
      hintText: l10n.playerNameHint,
      confirmText: l10n.save,
      initialValue: profile.name,
    );

    if (result != null && result.isNotEmpty && result != profile.name) {
      profile.name = result;
      await ProfileStorage.saveProfile(profile);
      await _loadProfiles();
    }
  }

  Future<void> _pickProfileImage(ProfileData profile) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      final profileDir = Directory('profiles/${profile.id}');
      if (!await profileDir.exists()) {
        await profileDir.create(recursive: true);
      }

      final imageExtension = pickedFile.name.contains('.')
          ? '.${pickedFile.name.split('.').last}'
          : '.png';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final destPath = '${profileDir.path}/profile_$timestamp$imageExtension';
      final destFile = File(destPath);

      if (await profileDir.exists()) {
        final oldImages = await profileDir
            .list()
            .where((entity) =>
                entity is File &&
                entity.path.contains('profile_'))
            .toList();
        for (final old in oldImages) {
          await (old as File).delete();
        }
      }

      await destFile.writeAsBytes(await pickedFile.readAsBytes());

      profile.profileImagePath = destPath;
      await ProfileStorage.saveProfile(profile);
      await _loadProfiles();
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileImageError)),
      );
    }
  }

  Future<void> _confirmDeleteProfile(ProfileData profile) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteProfile),
        content: Text(l10n.deleteProfileConfirm(profile.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ProfileStorage.deleteProfile(profile.id);
      await _loadProfiles();
    }
  }

  Future<void> _showCreateRestaurantDialog() async {
    if (_selectedProfile == null) return;
    final l10n = AppLocalizations.of(context)!;

    final result = await _showTextFormDialog(
      title: l10n.newRestaurant,
      labelText: l10n.restaurantName,
      hintText: l10n.restaurantNameHint,
      confirmText: l10n.create,
    );

    if (result != null && result.isNotEmpty) {
      await ProfileStorage.addRestaurantToProfile(
        _selectedProfile!.id,
        RestaurantData(name: result),
      );
      await _loadProfiles();
      _updateSelectedProfile();
    }
  }

  Future<void> _confirmDeleteRestaurant(int index) async {
    if (_selectedProfile == null) return;
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteRestaurant),
        content: Text(l10n.deleteRestaurantConfirm(_selectedProfile!.restaurants[index].name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ProfileStorage.removeRestaurantFromProfile(
        _selectedProfile!.id,
        index,
      );
      await _loadProfiles();
      _updateSelectedProfile();
      if (_selectedRestaurant != null &&
          !_selectedProfile!.restaurants.contains(_selectedRestaurant)) {
        _selectedRestaurant = null;
      }
    }
  }

  void _updateSelectedProfile() {
    if (_selectedProfile != null) {
      _selectedProfile = _findProfileById(_selectedProfile!.id);
    }
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

  void _switchLanguage() {
    final locale = widget.localeProvider.locale;
    if (locale.languageCode == 'de') {
      widget.localeProvider.setLocale(const Locale('en'));
    } else {
      widget.localeProvider.setLocale(const Locale('de'));
    }
  }

  Future<void> _login() async {
    if (_selectedProfile == null) return;

    final freshProfile = _findProfileById(_selectedProfile!.id);
    if (freshProfile == null) return;

    ObjectProfile().loadFromData(freshProfile);

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ScreenRestaurant(),
      ),
    );

    if (!mounted) return;
    await _loadProfiles();

    if (_selectedProfile != null) {
      final updated = _findProfileById(_selectedProfile!.id);
      if (updated != null) {
        _selectedProfile = updated;
      } else {
        _selectedProfile = null;
        _selectedRestaurant = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentThemeMode = AppTheme.themeModeNotifier.value;
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = widget.localeProvider.locale;

    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.appTitle} – Start'),
        actions: [
          // Language switch
          IconButton(
            icon: Text(
              currentLocale.languageCode.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            tooltip: currentLocale.languageCode == 'de' ? 'Switch to English' : 'Zu Deutsch wechseln',
            onPressed: _switchLanguage,
          ),
          IconButton(
            icon: Icon(
              switch (currentThemeMode) {
                ThemeMode.light => Icons.light_mode,
                ThemeMode.dark => Icons.dark_mode,
                ThemeMode.system => Icons.settings_brightness,
              },
            ),
            tooltip: l10n.themeToggle(currentThemeMode.name),
            onPressed: _toggleTheme,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSectionHeader(
                    context,
                    icon: Icons.people,
                    title: l10n.profileSection,
                    action: IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: l10n.newProfileTooltip,
                      onPressed: _showCreateProfileDialog,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildProfileList(context, theme),

                  const SizedBox(height: 24),

                  _buildSectionHeader(
                    context,
                    icon: Icons.restaurant,
                    title: l10n.restaurantSection,
                    action: IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: l10n.newRestaurantTooltip,
                      onPressed: _selectedProfile != null
                          ? _showCreateRestaurantDialog
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildRestaurantList(context, theme),

                  const SizedBox(height: 24),

                  FilledButton.icon(
                    icon: const Icon(Icons.login),
                    label: Text(
                      _selectedProfile != null
                          ? l10n.loginAs(_selectedProfile!.name)
                          : l10n.selectProfilePrompt,
                    ),
                    onPressed:
                        _selectedProfile != null ? _login : null,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget action,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: theme.textTheme.headlineSmall),
        const Spacer(),
        action,
      ],
    );
  }

  Widget _buildProfileList(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;

    if (_profiles.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Text(
              l10n.noProfilesYet,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _profiles.length,
      itemBuilder: (context, index) {
        final profile = _profiles[index];
        final isSelected = profile.id == _selectedProfile?.id;

        return Card(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : null,
          child: ListTile(
            leading: GestureDetector(
              onTap: () => _pickProfileImage(profile),
              child: CircleAvatar(
                backgroundColor: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                backgroundImage: profile.profileImagePath != null
                    ? FileImage(File(profile.profileImagePath!))
                    : null,
                child: profile.profileImagePath == null
                    ? Icon(
                        Icons.person,
                        color: isSelected
                            ? theme.colorScheme.onPrimary
                            : null,
                      )
                    : null,
              ),
            ),
            title: Text(profile.name),
            subtitle: Text(
              l10n.profileSubtitle(profile.id, _formatDate(profile.creationDate), profile.restaurants.length),
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected)
                  Icon(Icons.check_circle,
                      color: theme.colorScheme.primary)
                else
                  const SizedBox(width: 24),
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: l10n.renameProfileTooltip,
                  onPressed: () => _showRenameProfileDialog(profile),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: theme.colorScheme.error),
                  tooltip: l10n.deleteProfileTooltip,
                  onPressed: () => _confirmDeleteProfile(profile),
                ),
              ],
            ),
            onTap: () {
              setState(() {
                _selectedProfile =
                    isSelected ? null : profile;
                _selectedRestaurant = null;
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildRestaurantList(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;

    if (_selectedProfile == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Text(
              l10n.selectProfileFirst,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    final restaurants = _selectedProfile!.restaurants;

    if (restaurants.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Text(
              l10n.noRestaurantsYet,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: restaurants.length,
      itemBuilder: (context, index) {
        final restaurant = restaurants[index];
        final isSelected = restaurant == _selectedRestaurant;

        return Card(
          color: isSelected
              ? theme.colorScheme.secondaryContainer
              : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isSelected
                  ? theme.colorScheme.secondary
                  : theme.colorScheme.surfaceContainerHighest,
              child: restaurant.logoPath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.file(
                        File(restaurant.logoPath!),
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            Icon(Icons.restaurant,
                                color: isSelected
                                    ? theme
                                        .colorScheme.onSecondary
                                    : null),
                      ),
                    )
                  : Icon(Icons.restaurant,
                      color: isSelected
                          ? theme.colorScheme.onSecondary
                          : null),
            ),
            title: Text(restaurant.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected)
                  Icon(Icons.check_circle,
                      color: theme.colorScheme.secondary)
                else
                  const SizedBox(width: 24),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: theme.colorScheme.error),
                  tooltip: l10n.deleteRestaurantTooltip,
                  onPressed: () =>
                      _confirmDeleteRestaurant(index),
                ),
              ],
            ),
            onTap: () {
              setState(() {
                _selectedRestaurant =
                    isSelected ? null : restaurant;
              });
            },
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }
}