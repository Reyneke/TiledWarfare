import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/game_clock_service.dart';
import 'package:tiled_warfare/services/power_projection_service.dart';
import 'package:tiled_warfare/services/rival_service.dart';

/// Tests der PP-/Ranking-Auswertung (Kapitel 12/13): `PowerProjectionState`,
/// die im `WeeklyTickResult` mitgegebene Rangliste und die „Platz X von Y“-
/// Kennzahlen für die UI.
void main() {
  final base = DateTime(2026, 1, 1);

  RestaurantData restaurant({
    int budget = 20000,
    List<StaffData>? staff,
    String? district = 'Midtown',
    DateTime? lastSeenAt,
    DateTime? weekAnchorAt,
  }) =>
      RestaurantData(
        id: 1,
        name: 'Testrestaurant',
        district: district,
        budget: budget,
        lastSeenAt: lastSeenAt ?? base,
        weekAnchorAt: weekAnchorAt ?? base,
        staff: staff ?? const [],
      );

  StaffData cook() =>
      StaffData(name: 'Testkoch', imagePath: 'x.png', type: 'apprentice');

  group('GameClockService.powerProjectionState (Kapitel 12/13)', () {
    test('liefert Rangliste mit Spieler-Eintrag und gültigem Rang', () {
      final r = restaurant(staff: [cook()]);
      final pp = GameClockService.powerProjectionState(r, now: base);

      expect(pp.powerProjection, inInclusiveRange(
          0, EconomyBalance.powerProjectionDomainMax));
      expect(pp.standings.total, greaterThanOrEqualTo(1));
      expect(pp.playerRank, greaterThanOrEqualTo(1));
      expect(pp.playerRank, lessThanOrEqualTo(pp.standings.total));
      expect(pp.playerRank, pp.standings.playerRank);
      expect(pp.standings.entries.where((e) => e.isPlayer).length, 1);
      expect(pp.rivalCount, pp.standings.total - 1);
      expect(pp.incomeFactor, greaterThan(0));
    });

    test('ist deterministisch und idempotent (kein Tick nötig)', () {
      final r = restaurant(staff: [cook()]);
      final a = GameClockService.powerProjectionState(r, now: base);
      final b = GameClockService.powerProjectionState(r, now: base);
      expect(a.powerProjection, b.powerProjection);
      expect(a.playerRank, b.playerRank);
      expect(a.incomeFactor, b.incomeFactor);
      final ranksA =
          a.standings.entries.map((e) => '${e.rank}:${e.id}').toList();
      final ranksB =
          b.standings.entries.map((e) => '${e.rank}:${e.id}').toList();
      expect(ranksA, ranksB);
    });

    test('Rangliste ist absteigend nach PP sortiert', () {
      final r = restaurant(staff: [cook()]);
      final pp = GameClockService.powerProjectionState(r, now: base);
      final entries = pp.standings.entries;
      for (var i = 1; i < entries.length; i++) {
        expect(
          entries[i - 1].powerProjection,
          greaterThanOrEqualTo(entries[i].powerProjection),
        );
        expect(entries[i].rank, entries[i - 1].rank + 1);
      }
    });
  });

  group('WeeklyTickResult.standings', () {
    test('No-op enthält keine Rangliste', () {
      final r = restaurant(staff: [cook()]);
      final result =
          GameClockService.catchUp(r, base.add(const Duration(hours: 5)));
      expect(result.weeks, 0);
      expect(result.standings, isNull);
    });

    test('abgerechneter Wochenblock enthält die Rangliste', () {
      final r = restaurant(staff: [cook()]);
      final result =
          GameClockService.catchUp(r, base.add(const Duration(days: 7)));
      expect(result.weeks, 1);
      expect(result.standings, isNotNull);
      final standings = result.standings!;
      expect(standings.entries.where((e) => e.isPlayer).length, 1);
      expect(result.playerRank, standings.playerRank);
      expect(result.rivalCount, standings.total - 1);
    });

    test('Rangliste aus dem Tick stimmt mit der Auswertung überein', () {
      final r = restaurant(staff: [cook()]);
      final result =
          GameClockService.catchUp(r, base.add(const Duration(days: 7)));
      expect(result.standings, isNotNull);
      // Nach dem Tick ist der letzte Stand konsistent mit dem Endzustand.
      final recomputed = GameClockService.powerProjectionState(
        r,
        now: r.lastSeenAt,
      );
      expect(result.standings!.playerRank, recomputed.playerRank);
      expect(result.powerProjection, recomputed.powerProjection);
    });

    test('Rivalen-Pleite-Kennzeichnung folgt der Schwelle', () {
      final r = restaurant(staff: [cook()]);
      final result =
          GameClockService.catchUp(r, base.add(const Duration(days: 7)));
      final weekIndex = RivalService.weekIndexOf(base);
      for (final entry in result.standings!.entries) {
        if (entry.isPlayer) {
          expect(entry.insolvent, isFalse);
        } else {
          final rival = RivalService.byId(
            RivalService.candidatePool('Midtown'),
            entry.id,
          )!;
          expect(
            entry.insolvent,
            RivalService.simulatedRivalPp(
                  rival,
                  playerPp: result.powerProjection,
                  weekIndex: weekIndex,
                ) <
                EconomyBalance.rivalPpBankruptThreshold,
          );
        }
      }
    });
    test('Wochen-Tick verdrahtet den Konkurrenzdruck in den Einkommensfaktor',
        () {
      final r = restaurant(staff: [cook()]);
      final result =
          GameClockService.catchUp(r, base.add(const Duration(days: 7)));
      expect(result.standings, isNotNull);
      // Frisches Restaurant ⇒ Korruption zu Beginn 0, also ist der gebuchte
      // Faktor exakt das Produkt aus PP- und Konkurrenzdruck-Stufe (Q10).
      expect(
        result.incomeFactor,
        closeTo(
          PowerProjectionService.effectiveIncomeFactor(
            playerPp: result.powerProjection,
            rivalAveragePp: result.standings!.rivalAveragePp,
          ),
          1e-9,
        ),
      );
    });
  });
}
