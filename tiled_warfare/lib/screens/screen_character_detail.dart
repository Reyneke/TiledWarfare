import 'package:flutter/material.dart';
import 'package:tiled_warfare/models/match_record.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/objects/player_objects/object_apprentice.dart';
import 'package:tiled_warfare/objects/player_objects/object_line_cook.dart';

/// Detailbildschirm für einen Charakter.
///
/// Zeigt Bild, Statistiken, XP-Balken und Match-Historie des Charakters an.
/// Wird über einen Tap auf einen Charakter-Eintrag in [ScreenRestaurant] geöffnet.
/// Zeigt außerdem Teamarzt-Aktionen an, wenn ein Teamarzt angestellt ist.
class ScreenCharacterDetail extends StatelessWidget {
  /// Der anzuzeigende Charakter.
  final ObjectApprentice character;

  /// Das Spieler-Profil (Singleton, für Teamarzt-Zugriff).
  late final ObjectProfile _profile = ObjectProfile();

  ScreenCharacterDetail({super.key, required this.character});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLineCook = character is ObjectLineCook;

    return Scaffold(
      appBar: AppBar(
        title: Text(character.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Schließen',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header: Bild (links) + Statistiken (rechts) ──────────
            _buildHeader(context, theme, isLineCook),
            const SizedBox(height: 16),

            // ── Teamarzt-Aktionen ──────────────────────────────────
            _buildMedicActions(context, theme),
            const SizedBox(height: 16),

            // ── XP-Balken ────────────────────────────────────────────
            _buildXpBar(theme),
            const SizedBox(height: 24),

            // ── Match-Historie ───────────────────────────────────────
            Text(
              'Match-Historie',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            _buildMatchHistoryTable(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme, bool isLineCook) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Bild ──────────────────────────────────────────────────
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
                isLineCook ? Icons.restaurant : Icons.school,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),

        // ── Statistiken ────────────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rang & Name
              Text(
                isLineCook ? 'Line Cook' : 'Apprentice',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                character.name,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),

              // Status
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

              // Level
              Text('Level ${character.levelValue}',
                  style: theme.textTheme.bodyMedium),

              // LP / Wunden
              Text('LP: ${character.woundValue}',
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 4),

              // Kampfwerte
              Text(
                '⚔️ ${character.attackValue}  🛡️ ${character.defenseValue}  '
                '🏃 ${character.movementValue}  💥 ${character.damageValue}  '
                '🎯 ${character.rangeValue}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),

              // K/D-Ratio & Matches
              if (character.matchHistory.isNotEmpty) ...[
                Text(
                  'K/D: ${_formatKdRatio(character)}',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  'Matches: ${_wins(character)}S / ${_losses(character)}N / ${_draws(character)}U',
                  style: theme.textTheme.bodySmall,
                ),
              ] else
                Text(
                  'Noch keine Match-Daten',
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

  /// Baut die Teamarzt-Aktionsleiste, falls ein Teamarzt angestellt ist.
  Widget _buildMedicActions(BuildContext context, ThemeData theme) {
    final hasMedic = _profile.hiredMedics.isNotEmpty;
    if (!hasMedic) return const SizedBox.shrink();

    final needsTreat = character.status != CharacterStatus.ready;
    final needsEmergency = character.woundValue <= 0 ||
        character.status == CharacterStatus.dying;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.medical_services,
                color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text('Teamarzt:',
                style: theme.textTheme.labelLarge),
            const Spacer(),
            if (needsTreat)
              FilledButton.tonalIcon(
                icon: const Icon(Icons.healing, size: 18),
                label: const Text('Behandeln'),
                onPressed: () {
                  final medic = _profile.hiredMedics.first;
                  if (medic.treatCharacter(character)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '${character.name} wurde behandelt.'),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Behandlung fehlgeschlagen.'),
                      ),
                    );
                  }
                },
              ),
            if (needsTreat && needsEmergency) const SizedBox(width: 8),
            if (needsEmergency)
              FilledButton.tonalIcon(
                icon: const Icon(Icons.emergency, size: 18,
                    color: Colors.red),
                label: Text('Notfall-Spritze',
                    style: TextStyle(color: Colors.red[700])),
                onPressed: () {
                  final medic = _profile.hiredMedics.first;
                  if (medic.emergencyShot(character)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '${character.name} wurde eine Notfall-Spritze verabreicht.'),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Notfall-Spritze fehlgeschlagen.'),
                      ),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildXpBar(ThemeData theme) {
    final currentXp = character.currentXPValue;
    final threshold = character.levelValue * 1000;
    final progress = currentXp / threshold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'XP: $currentXp / $threshold',
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
              'Level-Aufstieg möglich!',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMatchHistoryTable(ThemeData theme) {
    if (character.matchHistory.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Text(
              'Keine Match-Historie vorhanden.',
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
            0: FlexColumnWidth(2), // Datum
            1: FlexColumnWidth(2), // Gegner
            2: FlexColumnWidth(1), // Ergebnis
            3: FlexColumnWidth(1), // K/D
            4: FlexColumnWidth(2), // Notizen
          },
          border: TableBorder.all(
            color: theme.colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(4),
          ),
          children: [
            // Header
            TableRow(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              children: [
                _tableCell('Datum', isHeader: true),
                _tableCell('Gegner', isHeader: true),
                _tableCell('Ergebnis', isHeader: true),
                _tableCell('K/D', isHeader: true),
                _tableCell('Ereignisse', isHeader: true),
              ],
            ),
            // Daten
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
    if (totalDeaths == 0) return '${totalKills}.0';
    return (totalKills / totalDeaths).toStringAsFixed(1);
  }

  int _wins(ObjectApprentice c) =>
      c.matchHistory.where((m) => m.result == MatchResult.win).length;
  int _losses(ObjectApprentice c) =>
      c.matchHistory.where((m) => m.result == MatchResult.loss).length;
  int _draws(ObjectApprentice c) =>
      c.matchHistory.where((m) => m.result == MatchResult.draw).length;
}