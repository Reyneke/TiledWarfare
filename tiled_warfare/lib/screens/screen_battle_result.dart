import 'package:flutter/material.dart';
import 'package:tiled_warfare/objects/object_player.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/objects/player_objects/object_apprentice.dart';
import 'package:tiled_warfare/objects/object_team_medic.dart';
import 'package:tiled_warfare/models/match_record.dart';

/// Ergebnis-Bildschirm nach einem Kampf.
///
/// Zeigt Sieg/Niederlage an, verteilt XP an überlebende Charaktere
/// und gibt dem Spieler die Möglichkeit zurück ins Restaurant zu gehen.
class ScreenBattleResult extends StatefulWidget {
  /// `true` = Spieler hat gewonnen, `false` = verloren.
  final bool playerWon;

  /// Name der Karte/Gegners (z. B. "Dough Dumpster").
  final String opponentName;

  const ScreenBattleResult({
    super.key,
    required this.playerWon,
    required this.opponentName,
  });

  @override
  State<ScreenBattleResult> createState() => _ScreenBattleResultState();
}

class _ScreenBattleResultState extends State<ScreenBattleResult> {
  final ObjectProfile _profile = ObjectProfile();
  final ObjectPlayer _player = ObjectPlayer();
  List<_CharacterResult> _characterResults = [];
  int _totalXpGained = 0;
  int _survivors = 0;
  int _fallen = 0;

  @override
  void initState() {
    super.initState();
    _computeAndApplyResults();
  }

  void _computeAndApplyResults() {
    // battleRoster enthält alle Einheiten, die in die Schlacht gezogen sind
    // (inkl. gefallener). unitList enthält nur die Überlebenden.
    final allUnits = _player.battleRoster;
    final survivors = _player.unitList;
    final results = <_CharacterResult>[];
    int survivorCount = 0;
    int fallenCount = 0;
    int totalXpGained = 0;

    for (final unit in allUnits) {
      final xpGained = widget.playerWon ? _xpForWin(unit.levelValue) : _xpForLoss;
      final oldLevel = unit.levelValue;

      if (xpGained > 0) {
        unit.earnXP(xpGained);
      }

      final leveledUp = unit.levelValue > oldLevel;
      final isAlive = unit.woundValue > 0;

      results.add(_CharacterResult(
        name: unit.name,
        characterType: _characterDisplayType(unit),
        wasAlive: isAlive,
        oldLevel: oldLevel,
        newLevel: unit.levelValue,
        xpGained: xpGained,
        leveledUp: leveledUp,
      ));

      if (isAlive) {
        survivorCount++;
        totalXpGained += xpGained;
      } else {
        fallenCount++;
      }
    }

    // Match-Record hinzufügen
    _profile.addMatchRecordsForBattle(
      opponentName: widget.opponentName,
      result: widget.playerWon ? MatchResult.win : MatchResult.loss,
    );

    // Sync units + save (fire-and-forget with error handling)
    // Nur die Überlebenden (unitList) an syncUnitsAfterBattle übergeben,
    // da ObjectProfile._performSurvivalRolls() die Gefallenen aus _personal
    // selbst ermittelt und Rettungswürfe durchführt.
    _profile.syncUnitsAfterBattle(survivors);
    _profile.saveToStorage().catchError((Object error) {
      debugPrint('Failed to save profile after battle: $error');
      return false;
    });

    _characterResults = results;
    _survivors = survivorCount;
    _fallen = fallenCount;
    _totalXpGained = totalXpGained;
  }

  /// XP-Berechnung bei Sieg: Basis 50 + 10 pro Level + Bonus für Überlebende.
  static int _xpForWin(int level) => 50 + (level * 10);

  /// XP-Berechnung bei Niederlage: nur 10 XP.
  static const int _xpForLoss = 10;

  /// Liefert einen lesbaren Anzeigenamen für den Charakter-Typ.
  static String _characterDisplayType(ObjectApprentice unit) {
    if (unit is ObjectTeamMedic) return 'Medic';
    // Extrahiert den Klassennamen ohne 'Object'-Präfix.
    // z. B. ObjectLineCook → LineCook, ObjectApprentice → Apprentice
    final fullType = unit.runtimeType.toString();
    final simpleName = fullType.contains('.')
        ? fullType.split('.').last
        : fullType;
    return simpleName.startsWith('Object')
        ? simpleName.substring('Object'.length)
        : simpleName;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false, // Nur über den Button zurück
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kampfergebnis'),
          automaticallyImplyLeading: false,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Kopfzeile: Sieg / Niederlage
              Icon(
                widget.playerWon ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                size: 80,
                color: widget.playerWon ? Colors.amber : Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                widget.playerWon ? '🎉 Sieg!' : '💀 Niederlage',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: widget.playerWon ? Colors.green : Colors.red,
                ),
              ),
              Text(
                'Gegen: ${widget.opponentName}',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Überlebende: $_survivors  ·  Gefallene: $_fallen',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              if (widget.playerWon)
                Text(
                  '⭐ Gesamt-XP: $_totalXpGained',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 24),

              // Charakter-Liste mit XP
              Text(
                'Einheiten',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              ..._characterResults.map((result) => _buildCharacterCard(result, theme)),

              const SizedBox(height: 24),

              // Button zurück zum Restaurant
              FilledButton.icon(
                icon: const Icon(Icons.arrow_back),
                label: const Text('Zurück zum Restaurant'),
                onPressed: () {
                  // Eine Ebene zurück zur Restaurant-Screen navigieren.
                  // Der Stack ist: ScreenStart → ScreenRestaurant → ScreenBattleResult
                  // pop() geht zurück zu ScreenRestaurant.
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCharacterCard(_CharacterResult result, ThemeData theme) {
    final statusColor = result.wasAlive ? Colors.green : Colors.grey;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: statusColor.withValues(alpha: 0.2),
              child: Icon(
                result.wasAlive ? Icons.person : Icons.person_off,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${result.characterType} · Level ${result.oldLevel}${result.leveledUp ? ' → ${result.newLevel} ⬆' : ''}',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (result.wasAlive && result.xpGained > 0)
                    Text(
                      '+${result.xpGained} XP',
                      style: TextStyle(
                        color: Colors.amber.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (!result.wasAlive)
                    const Text(
                      'Gefallen',
                      style: TextStyle(color: Colors.red),
                    ),
                ],
              ),
            ),
            if (result.leveledUp)
              const Icon(Icons.arrow_upward, color: Colors.green),
          ],
        ),
      ),
    );
  }
}

/// Ergebnis-Datensatz für einen einzelnen Charakter nach dem Kampf.
class _CharacterResult {
  final String name;
  final String characterType;
  final bool wasAlive;
  final int oldLevel;
  final int newLevel;
  final int xpGained;
  final bool leveledUp;

  const _CharacterResult({
    required this.name,
    required this.characterType,
    required this.wasAlive,
    required this.oldLevel,
    required this.newLevel,
    required this.xpGained,
    required this.leveledUp,
  });
}