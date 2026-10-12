import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/rival_service.dart';

/// Tests der **Fairness**-Zusagen der Gefechtsteilnahme (Kapitel 13, Q8):
/// Rivalen bringen nur Truppen ins Gefecht, die ihr simulierter Zustand
/// hergibt – keine versteckten Armeen, deterministische Reduktion.
void main() {
  final base = DateTime(2026, 1, 1);

  RestaurantData restaurant() => RestaurantData(
        id: 1,
        name: 'R',
        district: 'Midtown',
        budget: 20000,
        lastSeenAt: base,
        weekAnchorAt: base,
      );

  group('RivalService: Fairness (Q8)', () {
    test('Truppenstärke liegt immer zwischen 1 und dem Cap', () {
      for (var pp = 0; pp <= 100; pp++) {
        final size = RivalService.battleTeamSizeForPp(pp);
        expect(size, greaterThanOrEqualTo(1));
        expect(size, lessThanOrEqualTo(EconomyBalance.rivalBattleMaxTeamSize));
      }
    });

    test('Truppenstärke wächst monoton mit der PP', () {
      var previous = RivalService.battleTeamSizeForPp(0);
      for (var pp = 1; pp <= 100; pp++) {
        final current = RivalService.battleTeamSizeForPp(pp);
        expect(current, greaterThanOrEqualTo(previous));
        previous = current;
      }
      // An der Oberkante greift der Cap.
      expect(
        RivalService.battleTeamSizeForPp(1000),
        EconomyBalance.rivalBattleMaxTeamSize,
      );
    });

    test('Teilnehmerzahl bleibt im erlaubten Bereich (1–4, ≤ Roster)', () {
      final r = restaurant();
      final rosterSize = RivalService.rosterOf('Midtown').length;
      for (var playerPp = 0; playerPp <= 100; playerPp += 10) {
        final count = RivalService.battleParticipantCount(r, seed: playerPp);
        expect(count, greaterThanOrEqualTo(0));
        expect(count,
            lessThanOrEqualTo(EconomyBalance.rivalBattleMaxParticipants));
        expect(count, lessThanOrEqualTo(rosterSize));
        if (rosterSize > 0) {
          expect(count,
              greaterThanOrEqualTo(EconomyBalance.rivalBattleMinParticipants));
        }
      }
    });

    test('stärkste Rivalen (höchste PP) nehmen teil', () {
      final r = restaurant();
      const playerPp = 50;
      final participants =
          RivalService.battleParticipantIds(r, playerPp: playerPp);
      if (participants.isEmpty) return;
      final roster = RivalService.rosterOf('Midtown');
      final pps = {
        for (final e in roster)
          e.id: RivalService.rivalPowerProjection(e, playerPp: playerPp),
      };
      final minTakenPp =
          participants.map((id) => pps[id]!).reduce((a, b) => a < b ? a : b);
      for (final e in roster) {
        if (participants.contains(e.id)) continue;
        // Kein Ausgeschlossener darf stärker sein als der schwächste Teilnehmer.
        expect(pps[e.id]!, lessThanOrEqualTo(minTakenPp + 1e-9));
      }
    });

    test('Spawn-Verteilung ist deterministisch und beschränkt', () {
      for (var participants = 1; participants <= 6; participants++) {
        for (var spawns = 1; spawns <= 4; spawns++) {
          final a = RivalService.distributeBattleSpawns(
              participantCount: participants, availableSpawns: spawns);
          final b = RivalService.distributeBattleSpawns(
              participantCount: participants, availableSpawns: spawns);
          expect(a, b);
          expect(a.length, participants);
          for (final idx in a) {
            expect(idx, lessThan(spawns));
            expect(idx, greaterThanOrEqualTo(0));
          }
        }
      }
    });
  });
}
