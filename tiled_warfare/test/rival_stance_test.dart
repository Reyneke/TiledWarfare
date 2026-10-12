import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/rival_service.dart';

/// Tests der deterministischen **Stance**-Ableitung und der Rivalen-
/// **Gefechtsteilnahme** aus Kapitel 13 (Q8/Q9).
void main() {
  final base = DateTime(2026, 1, 1);

  RestaurantData restaurant({
    String? district = 'Midtown',
    int budget = 20000,
  }) =>
      RestaurantData(
        id: 1,
        name: 'R',
        district: district,
        budget: budget,
        lastSeenAt: base,
        weekAnchorAt: base,
      );

  group('RivalService.stanceForRival (Q9: relative PP-Abstände)', () {
    test('gleiche PP ⇒ Verbündet (Abstand 0)', () {
      expect(
        RivalService.stanceForRival(rivalPp: 50, playerPp: 50),
        RivalStance.ally,
      );
    });

    test('kleiner Abstand (≤ 20 %) ⇒ Verbündet', () {
      // 100 vs 85 ⇒ 15 % Abstand.
      expect(
        RivalService.stanceForRival(rivalPp: 85, playerPp: 100),
        RivalStance.ally,
      );
      expect(
        RivalService.stanceForRival(rivalPp: 100, playerPp: 85),
        RivalStance.ally,
      );
    });

    test('mittlerer Abstand (≈ 50 %) ⇒ Neutral', () {
      // 100 vs 50 ⇒ 50 % Abstand.
      expect(
        RivalService.stanceForRival(rivalPp: 50, playerPp: 100),
        RivalStance.neutral,
      );
    });

    test('großer Abstand (≥ 80 %) ⇒ Feind', () {
      // 100 vs 10 ⇒ 90 % Abstand.
      expect(
        RivalService.stanceForRival(rivalPp: 10, playerPp: 100),
        RivalStance.enemy,
      );
    });

    test('Grenzen folgen den EconomyBalance-Schwellen', () {
      final allyBoundary =
          (EconomyBalance.stanceAllyGap + EconomyBalance.stanceNeutralGap) / 2;
      final enemyBoundary =
          (EconomyBalance.stanceNeutralGap + EconomyBalance.stanceEnemyGap) / 2;
      // 16 % < allyBoundary ⇒ Verbündet.
      expect(
        RivalService.stanceForRival(rivalPp: 100, playerPp: 84),
        RivalStance.ally,
        reason: '16 % < allyBoundary($allyBoundary)',
      );
      // 60 % liegt zwischen Neu- und Feind-Grenze ⇒ Neutral.
      expect(
        RivalService.stanceForRival(rivalPp: 100, playerPp: 40),
        RivalStance.neutral,
        reason: '60 % < enemyBoundary($enemyBoundary)',
      );
      // 70 % ≥ enemyBoundary ⇒ Feind.
      expect(
        RivalService.stanceForRival(rivalPp: 100, playerPp: 30),
        RivalStance.enemy,
      );
    });

    test('deterministisch (gleiche Eingabe ⇒ gleiche Haltung)', () {
      for (var playerPp = 0; playerPp <= 100; playerPp += 5) {
        for (var rivalPp = 0; rivalPp <= 100; rivalPp += 5) {
          final a = RivalService.stanceForRival(
              rivalPp: rivalPp, playerPp: playerPp);
          final b = RivalService.stanceForRival(
              rivalPp: rivalPp, playerPp: playerPp);
          expect(a, b);
        }
      }
    });
  });

  group('RivalService.battleParticipants (Q8/Q9)', () {
    test('deterministisch für gleiche Eingaben', () {
      final r = restaurant();
      final a = RivalService.battleParticipants(
        r,
        playerPp: 55,
        availableSpawns: EconomyBalance.rivalBattlePlayerSpawnCount,
      );
      final b = RivalService.battleParticipants(
        r,
        playerPp: 55,
        availableSpawns: EconomyBalance.rivalBattlePlayerSpawnCount,
      );
      expect(a.length, b.length);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].rivalId, b[i].rivalId);
        expect(a[i].stance, b[i].stance);
        expect(a[i].teamSize, b[i].teamSize);
        expect(a[i].spawnIndex, b[i].spawnIndex);
      }
    });

    test('Teilnehmer stammen aus dem Roster und sind höchstens 4', () {
      final r = restaurant();
      final rosterIds =
          RivalService.rosterOf('Midtown').map((e) => e.id).toSet();
      final participants = RivalService.battleParticipants(
        r,
        playerPp: 50,
        availableSpawns: EconomyBalance.rivalBattlePlayerSpawnCount,
      );
      expect(participants.length,
          lessThanOrEqualTo(EconomyBalance.rivalBattleMaxParticipants));
      for (final p in participants) {
        expect(rosterIds.contains(p.rivalId), isTrue);
      }
    });

    test('Teilnehmer-IDs stimmen mit battleParticipantIds überein', () {
      final r = restaurant();
      final ids = RivalService.battleParticipantIds(r, playerPp: 50);
      final participants = RivalService.battleParticipants(
        r,
        playerPp: 50,
        availableSpawns: EconomyBalance.rivalBattlePlayerSpawnCount,
      );
      expect(participants.map((p) => p.rivalId).toList(), ids);
    });

    test('Spawn-Indizes bleiben unter der Spawn-Anzahl (round-robin)', () {
      final r = restaurant();
      final participants = RivalService.battleParticipants(
        r,
        playerPp: 50,
        availableSpawns: 1,
      );
      for (final p in participants) {
        expect(p.spawnIndex, 0);
      }
    });
  });
}
