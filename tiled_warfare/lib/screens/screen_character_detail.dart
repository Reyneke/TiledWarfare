import 'package:flutter/material.dart';
import 'package:tiled_warfare/l10n/staff_rank.dart';
import 'package:tiled_warfare/models/match_record.dart';
import 'package:tiled_warfare/models/personality.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/models/stations.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/objects/player_objects/object_apprentice.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/economy_service.dart';
import 'package:tiled_warfare/services/game_clock_service.dart';
import 'package:tiled_warfare/services/stress_service.dart';
import 'package:tiled_warfare/l10n/app_localizations.dart';
class ScreenCharacterDetail extends StatefulWidget {
  final ObjectApprentice character;

  const ScreenCharacterDetail({super.key, required this.character});

  @override
  State<ScreenCharacterDetail> createState() => _ScreenCharacterDetailState();
}

class _ScreenCharacterDetailState extends State<ScreenCharacterDetail> {
  late final ObjectProfile _profile = ObjectProfile();

  ObjectApprentice get character => widget.character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(character.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.close,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, theme),
            const SizedBox(height: 16),
            _buildStationSection(context, theme),
            _buildMedicActions(context, theme),
            const SizedBox(height: 16),
            _buildXpBar(context, theme),
            const SizedBox(height: 24),
            Text(
              l10n.matchHistory,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            _buildMatchHistoryTable(context, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            character.imagePath,
            width: 120,
            height: 120,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 120,
              height: 120,
              color: theme.colorScheme.surfaceContainerHighest,
              child: Icon(
                _rankIcon(),
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rankLabel(l10n, character.rank),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                character.name,
                style: theme.textTheme.titleMedium,
              ),
              // V10 (Phase 5): Doppelrolle des Chef de cuisine.
              if (character.rank == kRankHeadChef)
                Text(
                  character.headChefRole == kHeadChefRoleActive
                      ? l10n.headChefRoleActive
                      : l10n.headChefRoleFormal,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              // V10 (Phase 7): laufender Wochenlohn des Charakters.
              Text(
                l10n.weeklyWage(_weeklyWage),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.favorite, size: 16,
                      color: _statusColor(character.status)),
                  const SizedBox(width: 4),
                  Text(
                    character.status.name,
                    style: TextStyle(color: _statusColor(character.status)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(l10n.level(character.levelValue),
                  style: theme.textTheme.bodyMedium),
              Text(l10n.hitPoints(GameClockService.woundValueFor(character.status)),
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(
                l10n.statsLine(
                  character.attackValue,
                  character.defenseValue,
                  character.movementValue,
                  character.damageValue,
                  character.rangeValue,
                ),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              // Persönlichkeit & Ressourcen (V9 § 2/§ 6).
              Text(
                l10n.personalityLabel(character.effectivePersonality.name),
                style: theme.textTheme.bodySmall,
              ),
              Text(
                l10n.resourcesLine(
                  character.vitalityCurrent,
                  character.moraleCurrent,
                ),
                style: theme.textTheme.bodySmall,
              ),
              if (_overrideInfoText(l10n) != null)
                Text(
                  _overrideInfoText(l10n)!,
                  style: theme.textTheme.bodySmall,
                ),
              if (_exhaustionMalus() > 0)
                Text(
                  l10n.resourceZeroMalus(_exhaustionMalus()),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              const SizedBox(height: 8),
              if (character.matchHistory.isNotEmpty) ...[
                Text(
                  l10n.kdRatio(_formatKdRatio(character)),
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  l10n.matchStats(
                    _wins(character),
                    _losses(character),
                    _draws(character),
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ] else
                Text(
                  l10n.noMatchData,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Rang-Symbol des Charakters (Karrierepfade, V10).
  IconData _rankIcon() => switch (character.rank) {
        kRankHeadChef => Icons.workspace_premium,
        kRankSousChef => Icons.restaurant_menu,
        kRankChefDePartie => Icons.restaurant_menu,
        kRankLineCook => Icons.restaurant,
        _ => Icons.school,
      };

  /// Wochenlohn des Charakters inkl. Thriftiness-Faktor (V10, Phase 7).
  int get _weeklyWage => EconomyService.staffWagePerWeek(
        character.rank,
        PersonalityTraits.forProfile(character.personalityId, character.id)
            .thriftiness,
      );

  /// Stations-Zeile (Karrierepfade, V10, Phase 4): zeigt die gewählte Station
  /// und öffnet – ab Rang `chef_de_partie` – den Stations-Dialog.
  Widget _buildStationSection(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    if (!EconomyService.isStationRank(character.rank)) {
      return const SizedBox.shrink();
    }
    final label = stationLabel(l10n, character.station);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.local_dining,
                color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.station, style: theme.textTheme.labelLarge),
                  Text(label ?? l10n.stationNone,
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _chooseStation(context),
              child: Text(l10n.stationChoose),
            ),
          ],
        ),
      ),
    );
  }

  /// Öffnet den Stations-Dialog und bucht die Wahl über [ObjectProfile].
  Future<void> _chooseStation(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.stationChoose),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(l10n.stationChooseHint,
                style: Theme.of(ctx).textTheme.bodySmall),
          ),
          for (final station in kAllStations)
            SimpleDialogOption(
              onPressed: _stationSelectable(station)
                  ? () => Navigator.pop(ctx, station)
                  : null,
              child: Text(_stationOptionText(l10n, station)),
            ),
        ],
      ),
    );
    if (selected == null || selected == character.station) return;
    if (!context.mounted) return;

    // Ein Wechsel (es ist bereits eine Station gewählt) ist kostenpflichtig.
    if (character.station != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.station),
          content: Text(
            l10n.stationSwitchConfirm(EconomyBalance.stationSwitchCost),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.stationChoose),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final assigned = _profile.assignStation(character, selected);
    if (!mounted) return;
    setState(() {});
    if (assigned) await _profile.saveToStorage();
    if (!context.mounted) return;
    final message = assigned
        ? '${l10n.station}: ${stationLabel(l10n, selected) ?? selected}'
        : l10n.stationNotAllowed;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// `true`, wenn [station] für diesen Charakter wählbar ist: Basis-Stationen
  /// immer, Varianten erst nach Wahl ihrer Basis-Station (eine Variante
  /// derselben Basis bleibt wählbar).
  bool _stationSelectable(String station) {
    final base = EconomyService.baseStationOf(station);
    if (base == null) return true;
    final current = character.station;
    if (current == null) return false;
    return (EconomyService.baseStationOf(current) ?? current) == base;
  }

  /// Beschriftung einer Stations-Option inkl. Varianten-Hinweis und Haken.
  String _stationOptionText(AppLocalizations l10n, String station) {
    final label = stationLabel(l10n, station) ?? station;
    final base = EconomyService.baseStationOf(station);
    final baseLabel = base == null ? null : stationLabel(l10n, base);
    final marker = character.station == station ? ' ✓' : '';
    if (baseLabel == null) return '$label$marker';
    return '$label · ${l10n.stationVariantOf(baseLabel)}$marker';
  }

  Widget _buildMedicActions(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final hasMedic = _profile.hiredMedics.isNotEmpty;
    if (!hasMedic) return const SizedBox.shrink();

    final needsTreat = character.status != CharacterStatus.ready;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.medical_services,
                color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(l10n.teamMedic,
                style: theme.textTheme.labelLarge),
            const Spacer(),
            if (needsTreat) ...[
              Text(_healingInfoText(l10n), style: theme.textTheme.bodySmall),
              const SizedBox(width: 8),
            ],
            if (needsTreat)
              FilledButton.tonalIcon(
                icon: const Icon(Icons.healing, size: 18),
                label: Text(l10n.treat),
                onPressed: () {
                  setState(() {
                    final medic = _profile.hiredMedics.first;
                    if (medic.treatCharacter(character)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.treatmentSuccess(character.name)),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.treatmentFailed),
                        ),
                      );
                    }
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Countdown-Text für die laufende Heilung bzw. den Spritzen-Rückfall (V3).
  String _healingInfoText(AppLocalizations l10n) {
    final now = DateTime.now();
    if (character.emergencyShotAt != null) {
      final remaining =
          GameClockService.remainingShotTime(character.emergencyShotAt, now);
      return l10n.shotCountdown(remaining.inHours, remaining.inMinutes % 60);
    }
    final perStage = GameClockService.healTimePerStageFor(
      quality: GameClockService.bestHiredQuality(_profile.hiredMedics),
    );
    final remaining = GameClockService.remainingHealingTime(
      status: character.status,
      injuryStartedAt: character.injuryStartedAt,
      perStage: perStage,
      now: now,
    );
    return l10n.healCountdown(remaining.inHours, remaining.inMinutes % 60);
  }

  /// Text des laufenden Stress-/Ruhe-Overrides (V9 § 6) oder `null`.
  String? _overrideInfoText(AppLocalizations l10n) {
    final until = character.personalityOverrideUntil;
    if (until == null || !until.isAfter(DateTime.now())) return null;
    final time = '${until.day}.${until.month}. ${until.hour}:'
        '${until.minute.toString().padLeft(2, '0')}';
    return character.personalityOverrideCause == 'ruhe'
        ? l10n.ruheCountdown(time)
        : l10n.stressCountdown(time);
  }

  /// Aktueller Erschöpfungs-Malus in Prozentpunkten (V9 § 6).
  int _exhaustionMalus() =>
      StressService.malusPercentForCharacter(character, DateTime.now());

  Widget _buildXpBar(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final currentXp = character.currentXPValue;
    final threshold = EconomyService.levelUpThreshold(character.levelValue);
    final progress = currentXp / threshold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.xpLabel(currentXp, threshold),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 12,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              progress >= 1.0
                  ? Colors.green
                  : theme.colorScheme.primary,
            ),
          ),
        ),
        if (progress >= 1.0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.levelUpPossible,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMatchHistoryTable(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;

    if (character.matchHistory.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Text(
              l10n.noMatchHistory,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(1),
            3: FlexColumnWidth(1),
            4: FlexColumnWidth(2),
          },
          border: TableBorder.all(
            color: theme.colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(4),
          ),
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              children: [
                _tableCell(l10n.tableDate, isHeader: true),
                _tableCell(l10n.tableOpponent, isHeader: true),
                _tableCell(l10n.tableResult, isHeader: true),
                _tableCell(l10n.tableKD, isHeader: true),
                _tableCell(l10n.tableEvents, isHeader: true),
              ],
            ),
            for (final match in character.matchHistory)
              TableRow(
                children: [
                  _tableCell(
                    '${match.date.day}.${match.date.month}.${match.date.year}',
                  ),
                  _tableCell(match.opponentName),
                  _tableCell(match.result.name),
                  _tableCell('${match.kills}/${match.deaths}'),
                  _tableCell(match.notes ?? ''),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _tableCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isHeader ? 13 : 12,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Color _statusColor(CharacterStatus status) {
    switch (status) {
      case CharacterStatus.ready:
        return Colors.green;
      case CharacterStatus.reeling:
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

  String _formatKdRatio(ObjectApprentice c) {
    final totalKills = c.matchHistory.fold(0, (sum, m) => sum + m.kills);
    final totalDeaths = c.matchHistory.fold(0, (sum, m) => sum + m.deaths);
    if (totalDeaths == 0) return '$totalKills.0';
    return (totalKills / totalDeaths).toStringAsFixed(1);
  }

  int _wins(ObjectApprentice c) =>
      c.matchHistory.where((m) => m.result == MatchResult.win).length;
  int _losses(ObjectApprentice c) =>
      c.matchHistory.where((m) => m.result == MatchResult.loss).length;
  int _draws(ObjectApprentice c) =>
      c.matchHistory.where((m) => m.result == MatchResult.draw).length;
}