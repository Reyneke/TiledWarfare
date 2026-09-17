import 'package:flutter/material.dart';
import 'package:tiled_warfare/l10n/support_role_labels.dart';
import 'package:tiled_warfare/models/medic_quality.dart';
import 'package:tiled_warfare/models/personality.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/models/support_role.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/objects/object_team_medic.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/economy_service.dart';
import 'package:tiled_warfare/services/support_role_service.dart';
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
      _availablePersonnel.add(ObjectTeamMedic(
        teamSize: _profile.personalCount,
        nameZone: _profile.activeCuisine.zone,
      ));
    }
  }

  Future<void> _hireMedic(ObjectTeamMedic medic) async {
    setState(() {
      _availablePersonnel.remove(medic);
      _profile.hireMedic(medic);
    });
    await _saveWithFeedback();
  }

  Future<void> _fireMedic(ObjectTeamMedic medic) async {
    setState(() {
      _profile.fireMedic(medic);
    });
    await _saveWithFeedback();
  }

  /// Stellt eine Hilfs-/Service-Rolle ein (V10, Phase 6).
  Future<void> _hireSupportRole(SupportRole role) async {
    setState(() {
      _profile.hireSupportRole(role);
    });
    await _saveWithFeedback();
  }

  /// Entlässt eine Hilfs-/Service-Rolle (V10, Phase 6).
  Future<void> _fireSupportRole(SupportRoleData entry) async {
    setState(() {
      _profile.fireSupportRole(entry);
    });
    await _saveWithFeedback();
  }

  /// Gesamte Wochenlast: Arztkosten + Support-Löhne + Personal-Löhne (V10).
  int get _totalWeeklyLoad {
    final medicCosts = _profile.hiredMedics
        .fold<int>(0, (sum, medic) => sum + medic.costPerWeek);
    final supportCosts = SupportRoleService.weeklyWages(_profile.supportStaff);
    final staffCosts = _profile.personal.fold<int>(0, (sum, character) {
      final traits =
          PersonalityTraits.forProfile(character.personalityId, character.id);
      return sum + EconomyService.staffWagePerWeek(character.rank, traits.thriftiness);
    });
    return medicCosts + supportCosts + staffCosts;
  }

  /// Speichert den Spielstand und meldet einen Fehlschlag sichtbar (V6/L4).
  Future<void> _saveWithFeedback() async {
    final ok = await _profile.saveToStorage();
    if (ok || !mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.saveFailed)),
    );
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
              height: 200,
              child: _buildPersonnelList(
                context,
                _profile.hiredMedics,
                isHired: true,
              ),
            ),
            const Divider(),
          ],
          if (_profile.supportStaffCount > 0) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                l10n.hiredPersonnel(_profile.supportStaffCount),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            SizedBox(
              height: 120,
              child: _buildHiredSupportList(context),
            ),
            const Divider(),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              l10n.supportRoles,
              style: theme.textTheme.titleMedium,
            ),
          ),
          SizedBox(
            height: 180,
            child: _buildAvailableRoles(context),
          ),
          const Divider(),
          if (_profile.hiredMedicsCount > 0 ||
              _profile.supportStaffCount > 0 ||
              _profile.personalCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  l10n.weeklyLoadTotal(_totalWeeklyLoad),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ),
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

  /// Liste der angestellten Hilfs-/Service-Rollen (V10, Phase 6).
  Widget _buildHiredSupportList(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      scrollDirection: Axis.horizontal,
      itemCount: _profile.supportStaffCount,
      itemBuilder: (context, index) {
        final entry = _profile.supportStaff[index];
        final label = supportRoleLabelFor(l10n, entry.role) ?? entry.role;
        return SizedBox(
          width: 220,
          child: Card(
            margin: const EdgeInsets.all(4),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _fireSupportRole(entry),
                      icon: const Icon(Icons.person_remove, size: 18),
                      label: Text(l10n.fire),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Auswahlkarten aller Hilfs-/Service-Rollen (V10, Phase 6).
  Widget _buildAvailableRoles(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      scrollDirection: Axis.horizontal,
      itemCount: kAllSupportRoles.length,
      itemBuilder: (context, index) {
        final role = kAllSupportRoles[index];
        final wage = EconomyBalance.supportRoleWagePerWeek[role] ?? 0;
        return SizedBox(
          width: 220,
          child: Card(
            margin: const EdgeInsets.all(4),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    supportRoleLabel(l10n, role),
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    supportRoleEffectLabel(l10n, role),
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Text(
                    l10n.costPerWeek(wage),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _hireSupportRole(role),
                      icon: const Icon(Icons.person_add, size: 18),
                      label: Text(l10n.hire),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
                  Expanded(
                    child: Text(
                      l10n.costPerWeek(medic.costPerWeek),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
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
                      '${medic.enneagramProfile.name} · ${l10n.medicScores(
                        ObjectTeamMedic.helpfulnessScoreFor(
                            medic.enneagramProfile, medic.quality),
                        ObjectTeamMedic.treatmentQualityScoreFor(
                            medic.enneagramProfile, medic.quality),
                      )}',
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