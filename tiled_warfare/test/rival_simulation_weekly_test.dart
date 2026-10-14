import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/game_clock_service.dart';
import 'package:tiled_warfare/services/rival_service.dart';

/// Tests der **Wochen-Simulation** des Rivalen-Feldes (Kapitel 13,
/// „Voll-Simulation“): deterministischer Rivalen-Zustand, Roster-Dynamik
/// (Pleite/Nachrücken/Tuning der Ziel-Anzahl) und die **1-Tick-Verzögerung**.
void main() {
  final base = DateTime(2026, 1, 6); // == EconomyBalance.rivalSimulationEpoch

  RestaurantData restaurant({DateTime? weekAnchorAt}) => RestaurantData(
        id: 1,
        name: 'Testrestaurant',
        district: 'Midtown',
        budget: 20000,
        lastSeenAt: weekAnchorAt ?? base,
        weekAnchorAt: weekAnchorAt ?? base,
      );

  group('RivalService.weekIndexOf', () {
    test('folgt dem Wochenanker deterministisch', () {
      expect(RivalService.weekIndexOf(null), 0);
      expect(RivalService.weekIndexOf(base), 0);
      expect(RivalService.weekIndexOf(base.add(const Duration(days: 6))), 0);
      expect(RivalService.weekIndexOf(base.add(const Duration(days: 7))), 1);
      expect(RivalService.weekIndexOf(base.add(const Duration(days: 20))), 2);
      // Vor der Epoche gibt es keine negativen Indizes.
      expect(
        RivalService.weekIndexOf(base.subtract(const Duration(days: 30))),
        0,
      );
    });

    test('ist idempotent (derselbe Anker ⇒ derselbe Index)', () {
      final anchor = base.add(const Duration(days: 63));
      expect(RivalService.weekIndexOf(anchor), RivalService.weekIndexOf(anchor));
    });
  });

  group('RivalService.candidatePool', () {
    test('hat die Pool-Größe und enthält den Roster als Präfix', () {
      final pool = RivalService.candidatePool('Midtown');
      expect(pool.length, EconomyBalance.rivalCountMax);
      final roster = RivalService.rosterOf('Midtown');
      expect(pool.length, greaterThanOrEqualTo(roster.length));
      for (var i = 0; i < roster.length; i++) {
        expect(pool[i].id, roster[i].id);
        expect(pool[i].name, roster[i].name);
        expect(pool[i].personalityId, roster[i].personalityId);
      }
    });

    test('ist deterministisch und namensstabil (Cache)', () {
      final a = RivalService.candidatePool('Chelsea');
      final b = RivalService.candidatePool('Chelsea');
      expect(a.length, b.length);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].id, b[i].id);
        expect(a[i].name, b[i].name);
      }
      expect(RivalService.candidatePool('Harlem').first.id, isNot(a.first.id));
    });
  });

  group('RivalService.simulatedRivalPp', () {
    test('startet in Woche 0 beim Mini-PP-Modell und wächst monoton', () {
      final rival = RivalService.candidatePool('Midtown').first;
      const playerPp = 50;
      final start = RivalService.simulatedRivalPp(
        rival,
        playerPp: playerPp,
        weekIndex: 0,
      );
      expect(
        start,
        closeTo(
          RivalService.rivalPowerProjection(rival, playerPp: playerPp),
          1e-9,
        ),
      );
      var previous = start;
      for (var w = 1; w <= EconomyBalance.rivalPpGrowthCapWeeks + 10; w++) {
        final value = RivalService.simulatedRivalPp(
          rival,
          playerPp: playerPp,
          weekIndex: w,
        );
        expect(value, greaterThanOrEqualTo(previous));
        expect(value, greaterThanOrEqualTo(EconomyBalance.rivalPpMin));
        expect(value, lessThanOrEqualTo(EconomyBalance.rivalPpMax));
        previous = value;
      }
    });

    test('ist gedeckelt (Cap-Wochen) und deterministisch', () {
      final rival = RivalService.candidatePool('Midtown').first;
      final capped = RivalService.simulatedRivalPp(
        rival,
        playerPp: 50,
        weekIndex: EconomyBalance.rivalPpGrowthCapWeeks,
      );
      final beyond = RivalService.simulatedRivalPp(
        rival,
        playerPp: 50,
        weekIndex: EconomyBalance.rivalPpGrowthCapWeeks + 500,
      );
      expect(beyond, capped);
    });

    test('wächst persönlichkeitsgetrieben (nicht für alle gleich)', () {
      final pool = RivalService.candidatePool('SoHo');
      final rates = <double>{};
      for (final rival in pool) {
        final w0 =
            RivalService.simulatedRivalPp(rival, playerPp: 50, weekIndex: 0);
        final w1 =
            RivalService.simulatedRivalPp(rival, playerPp: 50, weekIndex: 1);
        rates.add(w1 - w0);
      }
      expect(rates.length, greaterThan(1),
          reason: 'unterschiedliche Aggressivität ⇒ unterschiedliche Raten');
    });
  });

  group('RivalService.simulateField', () {
    test('ist deterministisch und idempotent', () {
      final a =
          RivalService.simulateField('Midtown', playerPp: 50, weekIndex: 5);
      final b =
          RivalService.simulateField('Midtown', playerPp: 50, weekIndex: 5);
      expect(a.activeCount, b.activeCount);
      expect(a.targetCount, b.targetCount);
      expect(a.playerRank, b.playerRank);
      expect(
        a.states.map((s) => '${s.rival.id}:${s.powerProjection}:${s.active}'),
        b.states.map((s) => '${s.rival.id}:${s.powerProjection}:${s.active}'),
      );
    });

    test('Invarianten: aktiv ⇒ im Pool, gesund und nie Pleite', () {
      final poolIds =
          RivalService.candidatePool('Midtown').map((r) => r.id).toSet();
      for (var w = 0; w <= 30; w++) {
        final sim = RivalService.simulateField(
          'Midtown',
          playerPp: 60,
          weekIndex: w,
          previousPlayerPp: 50,
        );
        expect(sim.activeCount, lessThanOrEqualTo(sim.targetCount));
        expect(sim.activeCount, lessThanOrEqualTo(EconomyBalance.rivalCountMax));
        for (final s in sim.activeStates) {
          expect(poolIds.contains(s.rival.id), isTrue);
          expect(
            s.powerProjection,
            greaterThanOrEqualTo(EconomyBalance.rivalPpBankruptThreshold),
          );
          expect(s.insolvent, isFalse);
        }
        for (final s in sim.states) {
          if (s.insolvent) {
            expect(s.active, isFalse,
                reason: 'eine Pleite darf nicht aktiv sein');
          }
        }
      }
    });

    test('Ziel-Anzahl reagiert auf die Vorwochen-Position (Q10)', () {
      final midtown = RivalService.countFor('Midtown');
      // Spieler führt die Vorwoche klar an ⇒ Feld wächst (Gegenwind).
      expect(
        RivalService.roamTargetCount('Midtown', playerPp: 100, weekIndex: 10),
        (midtown + EconomyBalance.rivalRosterLeadBonus)
            .clamp(EconomyBalance.rivalCountMin, EconomyBalance.rivalCountMax),
      );
      // Spieler war Vorwochen-Letzter ⇒ Feld schrumpft.
      expect(
        RivalService.roamTargetCount('Midtown', playerPp: 0, weekIndex: 10),
        (midtown - EconomyBalance.rivalRosterTrailPenalty)
            .clamp(EconomyBalance.rivalCountMin, EconomyBalance.rivalCountMax),
      );
      for (var pp = 0; pp <= 100; pp += 5) {
        final t =
            RivalService.roamTargetCount('Midtown', playerPp: pp, weekIndex: 7);
        expect(t, greaterThanOrEqualTo(EconomyBalance.rivalCountMin));
        expect(t, lessThanOrEqualTo(EconomyBalance.rivalCountMax));
      }
    });

    test('das Feld atmet: über die Wochen kommt es zu Austritten', () {
      var exits = 0;
      var previous = <int>{};
      for (var w = 0; w <= 40; w++) {
        final sim = RivalService.simulateField(
          'Midtown',
          playerPp: 30,
          weekIndex: w,
        );
        final now = sim.activeRivals.map((r) => r.id).toSet();
        if (w > 0) exits += previous.difference(now).length;
        previous = now;
      }
      expect(exits, greaterThan(0));
    });
  });

  group('RivalService.isRosterActive (1-Tick-Verzögerung)', () {
    test('gesund und in beiden Wochen im Zielbereich ⇒ aktiv', () {
      expect(
        RivalService.isRosterActive(
          healthyNow: true,
          healthyPrev: true,
          rankNow: 3,
          rankPrev: 3,
          targetNow: 4,
          targetPrev: 4,
        ),
        isTrue,
      );
    });

    test('erst jetzt in den Zielbereich gerückt ⇒ noch nicht aktiv', () {
      // Jetzt Platz 4 von Ziel 4, in der Vorwoche aber noch außerhalb (5).
      expect(
        RivalService.isRosterActive(
          healthyNow: true,
          healthyPrev: true,
          rankNow: 4,
          rankPrev: 5,
          targetNow: 4,
          targetPrev: 4,
        ),
        isFalse,
      );
      // Eine Woche später (Vorwoche war Platz 4) wird der Rivale aktiv.
      expect(
        RivalService.isRosterActive(
          healthyNow: true,
          healthyPrev: true,
          rankNow: 4,
          rankPrev: 4,
          targetNow: 4,
          targetPrev: 4,
        ),
        isTrue,
      );
    });

    test('Pleite (jetzt oder in der Vorwoche) ⇒ nie aktiv', () {
      expect(
        RivalService.isRosterActive(
          healthyNow: false,
          healthyPrev: true,
          rankNow: 1,
          rankPrev: 1,
          targetNow: 4,
          targetPrev: 4,
        ),
        isFalse,
      );
      expect(
        RivalService.isRosterActive(
          healthyNow: true,
          healthyPrev: false,
          rankNow: 1,
          rankPrev: 1,
          targetNow: 4,
          targetPrev: 4,
        ),
        isFalse,
      );
    });
  });

  group('RivalService.standings mit Wochen-Simulation', () {
    test('Rangliste enthält Spieler + aktive Rivalen, Ø = aktive PP', () {
      final r = restaurant();
      const weekIndex = 12;
      final sim = RivalService.simulateField(
        r.district,
        playerPp: 55,
        weekIndex: weekIndex,
      );
      final standings = RivalService.standings(
        r,
        playerPp: 55,
        weekIndex: weekIndex,
      );
      expect(standings.playerRank, sim.playerRank);
      expect(standings.rivalAveragePp, closeTo(sim.activeAveragePp, 1e-9));
      final entryIds = standings.entries.map((e) => e.id).toSet();
      for (final rival in sim.activeRivals) {
        expect(entryIds.contains(rival.id), isTrue);
      }
      for (var i = 0; i < standings.entries.length; i++) {
        expect(standings.entries[i].rank, i + 1);
        if (i > 0) {
          expect(
            standings.entries[i - 1].powerProjection,
            greaterThanOrEqualTo(standings.entries[i].powerProjection),
          );
        }
      }
    });

    test('ohne weekIndex bleibt das statische Alt-Verhalten erhalten', () {
      final r = restaurant();
      final standings = RivalService.standings(r, playerPp: 50);
      expect(standings.total, 1 + RivalService.rosterOf('Midtown').length);
    });
  });

  group('Wochentick-Integration', () {
    test('der Wochentick nutzt die simulierte Rangliste', () {
      final r = restaurant();
      final result =
          GameClockService.catchUp(r, base.add(const Duration(days: 7)));
      expect(result.standings, isNotNull);
      final recomputed = RivalService.standings(
        r,
        playerPp: result.powerProjection,
        weekIndex: RivalService.weekIndexOf(base),
      );
      expect(result.standings!.playerRank, recomputed.playerRank);
      expect(result.rivalCount, recomputed.total - 1);
    });
  });
}
