import 'package:flutter/material.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/objects/object_team_medic.dart';
import 'package:tiled_warfare/l10n/app_localizations.dart';

class ScreenHireAndFire extends StatefulWidget {
  const ScreenHireAndFire({super.key});

  @override
  State<ScreenHireAndFire> createState() => _ScreenHireAndFireState();
}

class _ScreenHireAndFireState extends State<ScreenHireAndFire> {
  final ObjectProfile _profile = ObjectProfile();
  final List<ObjectTeamMedic> _availablePersonnel = [];
  static const int _poolSize = 15;

  @override
  void initState() {
    super.initState();
    _generateAvailablePersonnel();
  }

  void _generateAvailablePersonnel() {
    _availablePersonnel.clear();
    for (var i = 0; i < _poolSize; i++) {
      _availablePersonnel.add(ObjectTeamMedic());
    }
  }

  void _hireMedic(ObjectTeamMedic medic) {
    setState(() {
      _availablePersonnel.remove(medic);
      _profile.hireMedic(medic);
    });
    _profile.saveToStorage();
  }

  void _fireMedic(ObjectTeamMedic medic) {
    setState(() {
      _profile.fireMedic(medic);
    });
    _profile.saveToStorage();
  }

  void _regeneratePool() {
    setState(() {
      _availablePersonnel.clear();
      _generateAvailablePersonnel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.personnelManagement),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.regeneratePool,
            onPressed: _availablePersonnel.isNotEmpty ? _regeneratePool : null,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_profile.hiredMedicsCount > 0) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                l10n.hiredPersonnel(_profile.hiredMedicsCount),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.availableCandidates(_availablePersonnel.length),
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

  Widget _buildEmptyState(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
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
            l10n.noCandidatesAvailable,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _regeneratePool,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.generateNewPool),
          ),
        ],
      ),
    );
  }
}

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
    final l10n = AppLocalizations.of(context)!;

    String qualityLabel;
    Color qualityColor;
    IconData qualityIcon;

    switch (medic.quality) {
      case MedicQuality.niedrig:
        qualityLabel = l10n.qualityLow;
        qualityColor = Colors.grey;
        qualityIcon = Icons.medical_services_outlined;
      case MedicQuality.mittel:
        qualityLabel = l10n.qualityMedium;
        qualityColor = Colors.blue;
        qualityIcon = Icons.medical_services;
      case MedicQuality.hoch:
        qualityLabel = l10n.qualityHigh;
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
              Row(
                children: [
                  Icon(Icons.euro, size: 16, color: colorScheme.onSurface),
                  const SizedBox(width: 4),
                  Text(
                    l10n.costPerWeek(medic.costPerWeek),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
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
              SizedBox(
                width: double.infinity,
                child: isHired
                    ? OutlinedButton.icon(
                        onPressed: onFire,
                        icon: const Icon(Icons.person_remove, size: 18),
                        label: Text(l10n.fire),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.error,
                        ),
                      )
                    : FilledButton.icon(
                        onPressed: onHire,
                        icon: const Icon(Icons.person_add, size: 18),
                        label: Text(l10n.hire),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}