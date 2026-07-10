import 'package:flutter/material.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/objects/object_team_medic.dart';

/// Screen für das Anstellen und Entlassen von Zusatzpersonal.
///
/// Dieser Screen stellt eine Liste mit verfügbaren Zusatzpersonal
/// (z. B. einem Teamarzt aus [ObjectTeamMedic]) dar. Der Spieler kann
/// Personal anstellen (hiren) oder wieder entlassen (feuern). Wichtige
/// Informationen wie Name, Qualität, wöchentliche Kosten und Persönlichkeit
/// werden in der Liste angezeigt.
///
/// Aktuell wird nur [ObjectTeamMedic] als anstellbarer Typ unterstützt.
///
/// Alle Änderungen werden über [ObjectProfile] persistiert.
class ScreenHireAndFire extends StatefulWidget {
  const ScreenHireAndFire({super.key});

  @override
  State<ScreenHireAndFire> createState() => _ScreenHireAndFireState();
}

class _ScreenHireAndFireState extends State<ScreenHireAndFire> {
  final ObjectProfile _profile = ObjectProfile();

  /// Liste der momentan verfügbaren Kandidaten (zum Anheuern).
  final List<ObjectTeamMedic> _availablePersonnel = [];

  /// Anzahl der Kandidaten, die im Pool verfügbar sein sollen.
  static const int _poolSize = 15;

  @override
  void initState() {
    super.initState();
    _generateAvailablePersonnel();
  }

  /// Generiert einen neuen Pool an verfügbaren Kandidaten.
  void _generateAvailablePersonnel() {
    _availablePersonnel.clear();
    for (var i = 0; i < _poolSize; i++) {
      _availablePersonnel.add(ObjectTeamMedic());
    }
  }

  /// Stellt einen Kandidaten ein und persistiert die Änderung.
  void _hireMedic(ObjectTeamMedic medic) {
    setState(() {
      _availablePersonnel.remove(medic);
      _profile.hireMedic(medic);
    });
    _profile.saveToStorage();
  }

  /// Entlässt einen angestellten Arzt und persistiert die Änderung.
  void _fireMedic(ObjectTeamMedic medic) {
    setState(() {
      _profile.fireMedic(medic);
    });
    _profile.saveToStorage();
  }

  /// Erzwingt eine vollständige Neugenerierung des Pools.
  void _regeneratePool() {
    setState(() {
      _availablePersonnel.clear();
      _generateAvailablePersonnel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalverwaltung'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Pool neu generieren',
            onPressed: _availablePersonnel.isNotEmpty ? _regeneratePool : null,
          ),
        ],
      ),
      body: Column(
        children: [
          // -- Angestellte --
          if (_profile.hiredMedicsCount > 0) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'Angestellte (${_profile.hiredMedicsCount})',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            SizedBox(
              height: 180,
              child: _buildPersonnelList(
                context,
                _profile.hiredMedics,
                isHired: true,
              ),
            ),
            const Divider(),
          ],

          // -- Verfügbare Kandidaten --
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Verfügbare Kandidaten (${_availablePersonnel.length})',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          ),
          Expanded(
            child: _availablePersonnel.isEmpty
                ? _buildEmptyState(theme)
                : _buildPersonnelList(
                    context,
                    _availablePersonnel,
                    isHired: false,
                  ),
          ),
        ],
      ),
    );
  }

  /// Baut eine horizontal scrollbare Liste von Personal-Karten.
  Widget _buildPersonnelList(
    BuildContext context,
    List<ObjectTeamMedic> personnel, {
    required bool isHired,
  }) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      scrollDirection: Axis.horizontal,
      itemCount: personnel.length,
      itemBuilder: (context, index) {
        final medic = personnel[index];
        return _PersonnelCard(
          medic: medic,
          isHired: isHired,
          onHire: isHired ? null : () => _hireMedic(medic),
          onFire: isHired ? () => _fireMedic(medic) : null,
        );
      },
    );
  }

  /// Baut den Leerzustand, wenn keine Kandidaten verfügbar sind.
  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_search,
            size: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'Keine Kandidaten verfügbar.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _regeneratePool,
            icon: const Icon(Icons.refresh),
            label: const Text('Neuen Pool generieren'),
          ),
        ],
      ),
    );
  }
}

/// Eine einzelne Karte, die einen Kandidaten oder Angestellten darstellt.
class _PersonnelCard extends StatelessWidget {
  final ObjectTeamMedic medic;
  final bool isHired;
  final VoidCallback? onHire;
  final VoidCallback? onFire;

  const _PersonnelCard({
    required this.medic,
    required this.isHired,
    required this.onHire,
    required this.onFire,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Qualität in Text und Farbe übersetzen.
    String qualityLabel;
    Color qualityColor;
    IconData qualityIcon;

    switch (medic.quality) {
      case MedicQuality.niedrig:
        qualityLabel = 'Niedrig';
        qualityColor = Colors.grey;
        qualityIcon = Icons.medical_services_outlined;
      case MedicQuality.mittel:
        qualityLabel = 'Mittel';
        qualityColor = Colors.blue;
        qualityIcon = Icons.medical_services;
      case MedicQuality.hoch:
        qualityLabel = 'Hoch';
        qualityColor = Colors.amber;
        qualityIcon = Icons.medical_services;
    }

    return Container(
      width: 220,
      margin: const EdgeInsets.all(4),
      child: Card(
        elevation: isHired ? 2 : 1,
        color: isHired
            ? colorScheme.primaryContainer.withValues(alpha: 0.5)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name + Status-Badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      medic.name,
                      style: theme.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isHired)
                    Icon(Icons.check_circle,
                        size: 18, color: colorScheme.primary),
                ],
              ),
              const SizedBox(height: 8),

              // Qualität
              Row(
                children: [
                  Icon(qualityIcon, size: 16, color: qualityColor),
                  const SizedBox(width: 6),
                  Text(
                    qualityLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: qualityColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Kosten
              Row(
                children: [
                  Icon(Icons.euro, size: 16, color: colorScheme.onSurface),
                  const SizedBox(width: 4),
                  Text(
                    '${medic.costPerWeek} € / Woche',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Persönlichkeit
              Row(
                children: [
                  Icon(Icons.psychology,
                      size: 16, color: colorScheme.onSurface),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      medic.enneagramProfile.name,
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Aktion-Button
              SizedBox(
                width: double.infinity,
                child: isHired
                    ? OutlinedButton.icon(
                        onPressed: onFire,
                        icon: const Icon(Icons.person_remove, size: 18),
                        label: const Text('Entlassen'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.error,
                        ),
                      )
                    : FilledButton.icon(
                        onPressed: onHire,
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Anstellen'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}