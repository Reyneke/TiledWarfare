import 'package:flutter/material.dart';
import 'package:tiled_warfare/l10n/management_feature_labels.dart';
import 'package:tiled_warfare/l10n/management_role_labels.dart';
import 'package:tiled_warfare/l10n/support_role_labels.dart';
import 'package:tiled_warfare/models/management_feature.dart';
import 'package:tiled_warfare/models/management_role.dart';
import 'package:tiled_warfare/models/medic_quality.dart';
import 'package:tiled_warfare/models/personality.dart';
import 'package:tiled_warfare/models/rival_restaurant.dart';
import 'package:tiled_warfare/models/staff_entry.dart';
import 'package:tiled_warfare/models/support_role.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/objects/object_team_medic.dart';
import 'package:tiled_warfare/objects/player_objects/object_apprentice.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/economy_service.dart';
import 'package:tiled_warfare/services/management_feature_service.dart';
import 'package:tiled_warfare/services/staff_role_service.dart';
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
      _availablePersonnel.add(
        ObjectTeamMedic(
          teamSize: _profile.personalCount,
          nameZone: _profile.activeCuisine.zone,
        ),
      );
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

  /// Stellt eine Verwaltungs-/Marketing-Rolle ein (Option C, `11a`).
  Future<void> _hireManagementRole(ManagementRole role) async {
    setState(() {
      _profile.hireManagementRole(role);
    });
    await _saveWithFeedback();
  }

  /// Entlässt einen Nicht-Kampf-Personal-Eintrag beliebiger Kategorie
  /// (Option C, `11a`).
  Future<void> _fireStaffEntry(StaffEntryData entry) async {
    setState(() {
      _profile.fireStaffEntry(entry);
    });
    await _saveWithFeedback();
  }

  /// Startet ein aktives Feature (`11a`): Ziel wählen → aktivieren → speichern.
  ///
  /// Die Einmalkosten bucht `ObjectProfile` unmittelbar beim Aktivieren ab; die
  /// Wirkung läuft danach über die Zeitanker des Catch-ups. Nicht jedes Feature
  /// hat ein Ziel: „Winkelzug“ und „Kreative Buchführung“ wirken ziel-los
  /// (E15/E16), die Sabotage zielt auf ein Rivalen-Restaurant (E14).
  Future<void> _startFeature(ManagementFeature feature) async {
    switch (feature) {
      case ManagementFeature.prCampaign:
        await _startPrCampaign(feature);
      case ManagementFeature.sabotage:
        await _startSabotage();
      case ManagementFeature.unionWorkers:
        await _startUnionWorkers();
      case ManagementFeature.legalTrick:
      case ManagementFeature.creativeAccounting:
      case ManagementFeature.rushHour:
      case ManagementFeature.organisationIsEverything:
      case ManagementFeature.storageTetris:
      case ManagementFeature.counterSabotage:
        await _startUntargetedFeature(feature);
    }
  }

  /// Schlagmannschaft für „Alle Räder …“ wählen und aktivieren (V12).
  ///
  /// Die Auswahl ist auf `ObjectProfile.unionWorkersTeamLimit`
  /// (Kompetenz × Schritt) begrenzt; die Aktivierung bucht die Einmalkosten
  /// unmittelbar (`ObjectProfile.activateUnionWorkers`).
  Future<void> _startUnionWorkers() async {
    final l10n = AppLocalizations.of(context)!;
    final limit = _profile.unionWorkersTeamLimit;
    final candidates = _profile.personal
        .where(
          (c) =>
              c.status != CharacterStatus.dying &&
              c.status != CharacterStatus.dead &&
              c.status != CharacterStatus.overkilled,
        )
        .toList();
    if (candidates.isEmpty || limit <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.managementFeatureNoTargets)));
      return;
    }
    final selected = <int>{};
    final team = await showDialog<List<ObjectApprentice>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocalState) => AlertDialog(
          title: Text(l10n.managementFeatureSelectTeam),
          content: SizedBox(
            width: 320,
            height: 320,
            child: ListView.builder(
              itemCount: candidates.length,
              itemBuilder: (context, index) {
                final c = candidates[index];
                final checked = selected.contains(c.id);
                return CheckboxListTile(
                  value: checked,
                  title: Text(c.name),
                  subtitle: Text('Lv ${c.levelValue}'),
                  onChanged: (value) => setLocalState(() {
                    if (value == true) {
                      if (selected.length < limit) selected.add(c.id);
                    } else {
                      selected.remove(c.id);
                    }
                  }),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(candidates.where((c) => selected.contains(c.id)).toList()),
              child: Text(l10n.managementFeatureActivate),
            ),
          ],
        ),
      ),
    );
    if (team == null || !mounted) return;
    final ok = _profile.activateUnionWorkers(team);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.managementFeatureActivationFailed)),
      );
      return;
    }
    setState(() {});
    await _saveWithFeedback();
  }

  /// Aktiviert ein ziel-loses Feature (Winkelzug, Kreative Buchführung).
  Future<void> _startUntargetedFeature(ManagementFeature feature) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = _profile.activateUntargetedFeature(feature);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.managementFeatureActivationFailed)),
      );
      return;
    }
    setState(() {});
    await _saveWithFeedback();
  }

  /// Startet die Sabotage gegen ein Rivalen-Restaurant der Chefsekretärin
  /// (`11a` E14 / Kapitel 13).
  ///
  /// Die Erfolgschance wird **deterministisch** aus der Personal-ID abgeleitet
  /// und im Dialog je Rivale angezeigt; die Auflösung erfolgt im nächsten
  /// Wochen-Tick (`RivalService.resolveSabotage`).
  Future<void> _startSabotage() async {
    final l10n = AppLocalizations.of(context)!;
    final rivals = _profile.rivals;
    if (rivals.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.managementSabotageNoRivals)));
      return;
    }
    final chance = _profile.sabotageSuccessPercent;
    final target = await showDialog<RivalRestaurant>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.managementSabotageSelectTarget),
        children: [
          for (final rival in rivals)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(rival),
              child: Text(
                '${rival.name} · '
                '${l10n.managementSabotageSuccessChance(chance)}',
              ),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
    if (target == null || !mounted) return;
    final ok = _profile.activateSabotage(target);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.managementFeatureActivationFailed)),
      );
      return;
    }
    setState(() {});
    await _saveWithFeedback();
  }

  /// PR-Kampagne: Ziel wählen → aktivieren → speichern (E7–E11).
  Future<void> _startPrCampaign(ManagementFeature feature) async {
    final l10n = AppLocalizations.of(context)!;
    final candidates = _profile.personal
        .where(
          (c) =>
              c.status != CharacterStatus.dying &&
              c.status != CharacterStatus.dead &&
              c.status != CharacterStatus.overkilled,
        )
        .toList();
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.managementFeatureNoTargets)));
      return;
    }

    final target = await showDialog<ObjectApprentice>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.managementFeatureSelectTarget),
        children: [
          for (final c in candidates)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(c),
              child: Text(
                '${c.name} · Lv ${c.levelValue} · '
                '${l10n.managementFeatureCost(_profile.managementFeatureCostFor(c))}',
              ),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );

    if (target == null || !mounted) return;
    final ok = _profile.activateManagementFeature(feature, target);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.managementFeatureActivationFailed)),
      );
      return;
    }
    setState(() {});
    await _saveWithFeedback();
  }

  /// Kurztext des Feature-Status eines Personal-Eintrags (aktiv/Nachwirkung).
  String? _featureStatusText(
    AppLocalizations l10n,
    StaffEntryData entry,
    ManagementFeature feature,
  ) {
    if (entry.activeFeature != feature.name) return null;
    final now = DateTime.now();
    // `11a` E14: Die Sabotage hat ein eigenes Vokabular (Auflösung im Wochentick
    // und Wirkungsfenster statt „Nachwirkung“).
    if (feature == ManagementFeature.sabotage) {
      if (_profile.managementFeatureIsActive(feature, now: now)) {
        return l10n.managementSabotagePending(
          _formatUntil(ManagementFeatureService.activeEndOf(entry)),
        );
      }
      final until = _profile.sabotageAppliedUntil;
      if (entry.featureResolvedAt != null &&
          until != null &&
          now.isBefore(until)) {
        return l10n.managementSabotageEffect(_formatUntil(until));
      }
    }
    // V13: „Rache ist Blutwurst“ ist reaktiv – solange scharf geschaltet, ist
    // der Gegenschlag bereit; nach einem ausgeführten Gegenschlag läuft das
    // Wirkungsfenster gegen den Angreifer (gleiches Vokabular wie die Sabotage).
    if (feature == ManagementFeature.counterSabotage) {
      if (_profile.managementFeatureIsActive(feature, now: now) &&
          entry.featureResolvedAt == null) {
        return l10n.managementCounterSabotagePending(
          _formatUntil(ManagementFeatureService.activeEndOf(entry)),
        );
      }
      final until = _profile.sabotageAppliedUntil;
      if (entry.featureResolvedAt != null &&
          until != null &&
          now.isBefore(until)) {
        return l10n.managementSabotageEffect(_formatUntil(until));
      }
    }
    if (_profile.managementFeatureIsActive(feature, now: now)) {
      return l10n.managementFeatureActive(
        _formatUntil(ManagementFeatureService.activeEndOf(entry)),
      );
    }
    if (_profile.managementFeatureIsInAftermath(feature, now: now)) {
      return l10n.managementFeatureAftermath(
        _formatUntil(ManagementFeatureService.aftermathEndOf(entry)),
      );
    }
    return null;
  }

  /// Icon je Feature (Aktivierungs-Button der Träger-Karte).
  IconData _featureIcon(ManagementFeature feature) => switch (feature) {
    ManagementFeature.prCampaign => Icons.campaign,
    ManagementFeature.sabotage => Icons.local_fire_department,
    ManagementFeature.legalTrick => Icons.gavel,
    ManagementFeature.creativeAccounting => Icons.calculate,
    ManagementFeature.rushHour => Icons.local_dining,
    ManagementFeature.organisationIsEverything => Icons.account_tree,
    ManagementFeature.storageTetris => Icons.inventory_2,
    ManagementFeature.unionWorkers => Icons.groups,
    ManagementFeature.counterSabotage => Icons.shield,
  };

  /// Beschriftung des Aktivierungs-Buttons; ziel-lose Features zeigen ihre
  /// Einmalkosten direkt am Button (`11a` E15/E16). „Organisation ist alles“
  /// zeigt stattdessen die **laufenden** Tageskosten (V12).
  String _featureButtonLabel(AppLocalizations l10n, ManagementFeature feature) {
    if (feature == ManagementFeature.organisationIsEverything) {
      return l10n.managementFeatureDailyCost(
        EconomyBalance.organisationCostPerDay,
      );
    }
    final cost = _profile.managementFeatureActivationCost(feature);
    if (cost <= 0) return l10n.managementFeatureActivate;
    return l10n.managementFeatureCost(cost);
  }

  /// Kompakte Zeitangabe (Tag.Monat Stunde:Minute) für Countdowns.
  String _formatUntil(DateTime? until) {
    if (until == null) return '—';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(until.day)}.${two(until.month)} '
        '${two(until.hour)}:${two(until.minute)}';
  }

  /// Gesamte Wochenlast: Arztkosten + Support-Löhne + Personal-Löhne (V10)
  /// plus die laufenden Tageskosten aktiver Features (V12).
  int get _totalWeeklyLoad {
    final medicCosts = _profile.hiredMedics.fold<int>(
      0,
      (sum, medic) => sum + medic.costPerWeek,
    );
    final supportCosts = StaffRoleService.nonCombatWeeklyWages(
      _profile.staffEntries,
    );
    final staffCosts = _profile.personal.fold<int>(0, (sum, character) {
      final traits = PersonalityTraits.forProfile(
        character.personalityId,
        character.id,
      );
      return sum +
          EconomyService.staffWagePerWeek(character.rank, traits.thriftiness);
    });
    // V12: „Organisation ist alles“ wird je aktivem Tag bezahlt.
    final featureCosts =
        ManagementFeatureService.featureDailyCosts(
          _profile.staffEntries,
          DateTime.now(),
        ) *
        7;
    return medicCosts + supportCosts + staffCosts + featureCosts;
  }

  /// Speichert den Spielstand und meldet einen Fehlschlag sichtbar (V6/L4).
  Future<void> _saveWithFeedback() async {
    final ok = await _profile.saveToStorage();
    if (ok || !mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.saveFailed)));
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
          if (_profile.staffEntries.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                l10n.hiredPersonnel(_profile.staffEntries.length),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            SizedBox(height: 220, child: _buildHiredSupportList(context)),
            const Divider(),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(l10n.supportRoles, style: theme.textTheme.titleMedium),
          ),
          SizedBox(height: 180, child: _buildAvailableRoles(context)),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              l10n.managementRoles,
              style: theme.textTheme.titleMedium,
            ),
          ),
          SizedBox(height: 180, child: _buildAvailableManagementRoles(context)),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              '${l10n.rivalsSection} · '
              '${l10n.rivalCount(_profile.rivals.length)}',
              style: theme.textTheme.titleMedium,
            ),
          ),
          SizedBox(height: 96, child: _buildRivalsSection(context)),
          const Divider(),
          if (_profile.hiredMedicsCount > 0 ||
              _profile.staffEntries.isNotEmpty ||
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

  /// Liste des angestellten Nicht-Kampf-Personals (Hilfs-/Service-Rollen und
  /// Verwaltung & Marketing; Option C, `11a`).
  Widget _buildHiredSupportList(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      scrollDirection: Axis.horizontal,
      itemCount: _profile.staffEntries.length,
      itemBuilder: (context, index) {
        final entry = _profile.staffEntries[index];
        final role = entry.kind == RoleKind.management
            ? managementRoleFromName(entry.role)
            : null;
        final label = entry.kind == RoleKind.management
            ? (managementRoleLabelFor(l10n, entry.role) ?? entry.role)
            : (supportRoleLabelFor(l10n, entry.role) ?? entry.role);
        final feature = role == null ? null : managementFeatureOf(role);
        final featureStatus = feature == null
            ? null
            : _featureStatusText(l10n, entry, feature);
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
                  if (feature != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      managementFeatureLabel(l10n, feature),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      managementFeatureEffectLabel(l10n, feature),
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (featureStatus != null)
                      Text(
                        featureStatus,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _startFeature(feature),
                          icon: Icon(_featureIcon(feature), size: 16),
                          label: Text(_featureButtonLabel(l10n, feature)),
                        ),
                      ),
                  ],
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _fireStaffEntry(entry),
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

  /// Kompakte Rivalen-Liste des Stadtteils (Minimal-Modul Kapitel 13):
  /// Name, Prestige und Sabotage-Status. Deterministisch aus `RivalService`.
  Widget _buildRivalsSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final rivals = _profile.rivals;
    final sabotagedUntil = _profile.sabotageAppliedUntil;
    final now = DateTime.now();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      scrollDirection: Axis.horizontal,
      itemCount: rivals.length,
      itemBuilder: (context, index) {
        final rival = rivals[index];
        final isSabotaged = rival.isSabotagedAt(
          _profile.sabotageTargetId,
          sabotagedUntil,
          now,
        );
        return SizedBox(
          width: 200,
          child: Card(
            margin: const EdgeInsets.all(4),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rival.name,
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${rival.basePrestige.toStringAsFixed(2)} · '
                    '${isSabotaged ? l10n.rivalSabotaged : rival.district}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isSabotaged
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Auswahlkarten aller Verwaltungs-/Marketing-Rollen (Option C, `11a`).
  Widget _buildAvailableManagementRoles(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      scrollDirection: Axis.horizontal,
      itemCount: kAllManagementRoles.length,
      itemBuilder: (context, index) {
        final role = kAllManagementRoles[index];
        final wage = EconomyBalance.managementRoleWagePerWeek[role] ?? 0;
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
                    managementRoleLabel(l10n, role),
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    managementRoleEffectLabel(l10n, role),
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
                      onPressed: () => _hireManagementRole(role),
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
                    Icon(
                      Icons.check_circle,
                      size: 18,
                      color: colorScheme.primary,
                    ),
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
                  Icon(
                    Icons.psychology,
                    size: 16,
                    color: colorScheme.onSurface,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${medic.enneagramProfile.name} · ${l10n.medicScores(ObjectTeamMedic.helpfulnessScoreFor(medic.enneagramProfile, medic.quality), ObjectTeamMedic.treatmentQualityScoreFor(medic.enneagramProfile, medic.quality))}',
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
