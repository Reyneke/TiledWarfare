import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/services/profile_storage.dart';
import 'package:tiled_warfare/screens/screen_restaurant.dart';
import 'package:tiled_warfare/theme/app_theme.dart';

/// Start-Bildschirm zur Verwaltung lokaler Nutzerdaten.
///
/// Bietet drei Hauptbereiche:
/// 1. **Profilverwaltung**: Liste der lokalen Profile + Buttons zum Verwalten.
/// 2. **Restaurantverwaltung**: Liste der Restaurants eines ausgewählten Profils
///    mit Logo + Buttons zum Verwalten.
/// 3. **Login-Button**: Mit dem ausgewählten Profil und Restaurant einloggen.
///
/// Beim Anlegen eines neuen Profils wird ein Dialog geöffnet, in dem der
/// Nutzer einen Namen eingibt. Es wird automatisch eine eindeutige CRC32-ID
/// generiert (Hash aus Name + Erstellungsdatum). Alle Daten werden lokal im
/// Ordner `profiles/<id>/` gespeichert.
class ScreenStart extends StatefulWidget {
  const ScreenStart({super.key});

  @override
  State<ScreenStart> createState() => _ScreenStartState();
}

class _ScreenStartState extends State<ScreenStart> {
  // ── State ──────────────────────────────────────────────────────────────
  /// Alle geladenen Profile.
  List<ProfileData> _profiles = [];

  /// Das aktuell ausgewählte Profil (für die Restaurantliste).
  ProfileData? _selectedProfile;

  /// Das aktuell ausgewählte Restaurant (für den Login).
  RestaurantData? _selectedRestaurant;

  /// Ladezustand.
  bool _isLoading = true;

  /// Theme-Mode (für AppBar-Umschaltung).
  ThemeMode _themeMode = ThemeMode.light;

  // ── Lifecycle ──────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _themeMode = AppTheme.themeModeNotifier.value;
    AppTheme.themeModeNotifier.addListener(_onThemeChanged);
    _loadProfiles();
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

  // ── Daten laden ────────────────────────────────────────────────────────
  Future<void> _loadProfiles() async {
    setState(() => _isLoading = true);
    final profiles = await ProfileStorage.loadAllProfiles();
    setState(() {
      _profiles = profiles;
      // Prüfen, ob das zuvor ausgewählte Profil noch existiert
      if (_selectedProfile != null &&
          !profiles.any((p) => p.id == _selectedProfile!.id)) {
        _selectedProfile = null;
        _selectedRestaurant = null;
      }
      _isLoading = false;
    });
  }

  // ── Profile erstellen ──────────────────────────────────────────────────
  Future<void> _showCreateProfileDialog() async {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Neues Profil'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Profilname',
              hintText: 'Name des Spielers',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Bitte gib einen Namen ein.';
              }
              return null;
            },
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(context, nameController.text.trim());
              }
            },
            child: const Text('Erstellen'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final newProfile = ProfileStorage.createProfile(result);
      await ProfileStorage.saveProfile(newProfile);
      await _loadProfiles();
    }
  }

  // ── Profil löschen ─────────────────────────────────────────────────────
  Future<void> _confirmDeleteProfile(ProfileData profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profil löschen'),
        content: Text(
          'Soll das Profil "${profile.name}" wirklich gelöscht werden?\n'
          'Alle zugehörigen Daten werden unwiderruflich entfernt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ProfileStorage.deleteProfile(profile.id);
      await _loadProfiles();
    }
  }

  // ── Restaurant erstellen ───────────────────────────────────────────────
  Future<void> _showCreateRestaurantDialog() async {
    if (_selectedProfile == null) return;

    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Neues Restaurant'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Restaurantname',
              hintText: 'Name des Restaurants',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Bitte gib einen Namen ein.';
              }
              return null;
            },
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(context, nameController.text.trim());
              }
            },
            child: const Text('Erstellen'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await ProfileStorage.addRestaurantToProfile(
        _selectedProfile!.id,
        RestaurantData(name: result),
      );
      await _loadProfiles();
      // Das ausgewählte Profil neu laden (Referenzen aktualisieren)
      _updateSelectedProfile();
    }
  }

  // ── Restaurant löschen ─────────────────────────────────────────────────
  Future<void> _confirmDeleteRestaurant(int index) async {
    if (_selectedProfile == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurant löschen'),
        content: Text(
          'Soll das Restaurant "${_selectedProfile!.restaurants[index].name}" '
          'wirklich gelöscht werden?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
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

  // ── Hilfsmethoden ──────────────────────────────────────────────────────
  /// Aktualisiert die [_selectedProfile]-Referenz nach Datenänderungen.
  void _updateSelectedProfile() {
    if (_selectedProfile != null) {
      _selectedProfile = _profiles.firstWhere(
        (p) => p.id == _selectedProfile!.id,
        orElse: () => _selectedProfile!,
      );
    }
  }

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

  /// Navigiert zum [ScreenRestaurant] mit den Daten des ausgewählten Profils.
  ///
  /// Lädt vor dem Navigieren die aktuellsten Profildaten aus dem Speicher in das
  /// [ObjectProfile]-Singleton, sodass der Restaurant-Bildschirm Budget, Personal,
  /// Profilbild usw. nutzen kann. Nach der Rückkehr werden die Profile neu geladen,
  /// damit Änderungen aus dem Restaurant-Bildschirm sichtbar werden.
  Future<void> _login() async {
    if (_selectedProfile == null) return;

    // Immer die frischesten Daten aus dem Storage laden, damit nicht versehentlich
    // eine veraltete In-Memory-Referenz ins ObjectProfile geschrieben wird.
    final profiles = await ProfileStorage.loadAllProfiles();
    final freshProfile = profiles.cast<ProfileData?>().firstWhere(
          (p) => p!.id == _selectedProfile!.id,
          orElse: () => null,
        );
    if (freshProfile == null) return;

    // Frische Profildaten in das ObjectProfile-Singleton laden
    ObjectProfile().loadFromData(freshProfile);

    // Warte auf die Rückkehr aus dem Restaurant-Bildschirm
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ScreenRestaurant(),
      ),
    );

    // Nach der Rückkehr: Profile neu laden, um geänderte Daten (Budget, Personal,
    // Profilbild) aus dem Storage zu übernehmen.
    if (!mounted) return;
    await _loadProfiles();

    // Das zuvor ausgewählte Profil im frischen Datenbestand suchen
    if (_selectedProfile != null) {
      final updated = _profiles.cast<ProfileData?>().firstWhere(
            (p) => p!.id == _selectedProfile!.id,
            orElse: () => null,
          );
      if (updated != null) {
        _selectedProfile = updated;
      } else {
        _selectedProfile = null;
        _selectedRestaurant = null;
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tiled Warfare – Start'),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── 1. Profilverwaltung ──────────────────────────────
                  _buildSectionHeader(
                    context,
                    icon: Icons.people,
                    title: 'Profile',
                    action: IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: 'Neues Profil',
                      onPressed: _showCreateProfileDialog,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildProfileList(context, theme),

                  const SizedBox(height: 24),

                  // ── 2. Restaurantverwaltung ──────────────────────────
                  _buildSectionHeader(
                    context,
                    icon: Icons.restaurant,
                    title: 'Restaurants',
                    action: IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: 'Neues Restaurant',
                      onPressed: _selectedProfile != null
                          ? _showCreateRestaurantDialog
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildRestaurantList(context, theme),

                  const SizedBox(height: 24),

                  // ── 3. Login-Button ──────────────────────────────────
                  FilledButton.icon(
                    icon: const Icon(Icons.login),
                    label: Text(
                      _selectedProfile != null
                          ? 'Einloggen als ${_selectedProfile!.name}'
                          : 'Bitte Profil auswählen',
                    ),
                    onPressed:
                        _selectedProfile != null ? _login : null,
                  ),
                ],
              ),
            ),
    );
  }

  // ── Section Header ─────────────────────────────────────────────────────
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

  // ── Profil-Liste ───────────────────────────────────────────────────────
  Widget _buildProfileList(BuildContext context, ThemeData theme) {
    if (_profiles.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Text(
              'Noch keine Profile vorhanden.\nErstelle ein neues Profil!',
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
            leading: CircleAvatar(
              backgroundColor: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.person,
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : null,
              ),
            ),
            title: Text(profile.name),
            subtitle: Text(
              'ID: ${profile.id}\n'
              'Erstellt: ${_formatDate(profile.creationDate)}\n'
              'Restaurants: ${profile.restaurants.length}',
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
                  icon: Icon(Icons.delete_outline,
                      color: theme.colorScheme.error),
                  tooltip: 'Profil löschen',
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

  // ── Restaurant-Liste ──────────────────────────────────────────────────
  Widget _buildRestaurantList(BuildContext context, ThemeData theme) {
    if (_selectedProfile == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Text(
              'Wähle zuerst ein Profil aus.',
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
              'Noch keine Restaurants vorhanden.\n'
              'Erstelle ein neues Restaurant!',
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
                        // ignore: undefined_hidden_name
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
                  tooltip: 'Restaurant löschen',
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

  // ── Hilfsfunktionen ──────────────────────────────────────────────────
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }
}