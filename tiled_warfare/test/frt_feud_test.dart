import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/frt_service.dart';
import 'package:tiled_warfare/services/game_clock_service.dart';
import 'package:tiled_warfare/services/rival_service.dart';

/// Kapitel 14, Paket **C2** (FRT-Fehde + Befreiung) und **Q7b** (offene
/// FRT-Angriffe auf Rivalen).
///
/// Geprüft wird, dass
/// - eine **aufgedeckte** FRT-Fehl-Attribution den *behaupteten* Rivalen für
///   `frtFeudWeeks` Wochen um eine Stufe feindlicher stimmt (Rangliste **und**
///   Gefecht),
/// - der Tick diese Fehde fortschreibt und der Spielstand sie über den
///   `ObjectProfile`-Pfad behält,
/// - die FRT Rivalen **offen** angreift (Q7b): ihre PP sinkt, fällt aber nie
///   unter die Pleite-Schwelle,
/// - ein Gefecht einen verlorenen Stadtteil **befreien** kann (Q4-Hysterese)
///   und das meldet.
void main() {
  final base = DateTime(2026, 1, 1, 12);

  /// Kampfpersonal mit zugewiesenen Profilen – nötig, damit die Entdeckung
  /// überhaupt greift (Ø-`shadiness` > 0, siehe `RivalService.averageShadiness`).
  List<StaffData> shadinessCrew() => [
    for (var id = 1; id <= 4; id++)
      StaffData(
        name: 'K$id',
        imagePath: 'x.png',
        type: kRankApprentice,
        rank: kRankApprentice,
        id: id,
        personalityId: id,
        levelValue: 3,
        vitalityCurrent: 50,
        moraleCurrent: 50,
        status: 'ready',
      ),
  ];

  RestaurantData restaurant({
    List<StaffData>? staff,
    double corruption = 0,
    bool districtLost = false,
    Map<int, int> feuds = const {},
    int budget = 20000,
    DateTime? anchor,
  }) => RestaurantData(
    id: 10,
    name: 'A',
    district: 'Midtown',
    budget: budget,
    staff: staff ?? const [],
    corruptionPercent: corruption,
    districtLost: districtLost,
    districtLostAt: districtLost ? (anchor ?? base) : null,
    frtFeudUntilWeekById: feuds,
    lastSeenAt: anchor ?? base,
    weekAnchorAt: anchor ?? base,
  );

  ProfileData oneRestaurant({
    double corruption = 0,
    bool districtLost = false,
    List<StaffData>? staff,
  }) => ProfileData(
    id: 1,
    name: 'Tester',
    creationDate: base,
    restaurants: [
      restaurant(
        staff: staff,
        corruption: corruption,
        districtLost: districtLost,
      ),
    ],
  );

  group('C2 – FRT-Fehde (Stance-Verschiebung)', () {
    test('escalateStance verschiebt eine Stufe Richtung Feind', () {
      expect(RivalService.escalateStance(RivalStance.ally), RivalStance.neutral);
      expect(
        RivalService.escalateStance(RivalStance.neutral),
        RivalStance.enemy,
      );
      expect(RivalService.escalateStance(RivalStance.enemy), RivalStance.enemy);
    });

    test('feudActiveFor läuft bis einschließlich des Wochen-Index', () {
      final r = restaurant(feuds: const {7: 12});
      expect(RivalService.feudActiveFor(r, 7, 11), isTrue);
      expect(RivalService.feudActiveFor(r, 7, 12), isTrue);
      expect(RivalService.feudActiveFor(r, 7, 13), isFalse);
      expect(RivalService.feudActiveFor(r, 8, 12), isFalse);
    });

    test('applyFrtFeud setzt die Fehde für den behaupteten Rivalen', () {
      final r = restaurant(anchor: base);
      final roster = RivalService.rosterOf(r.district);
      final attacker = roster.first.id;
      final outcome = IncomingSabotageOutcome(
        blockAnchor: base,
        attackerIds: [attacker],
        detectedIds: [attacker],
        detectionPercent: 100,
        counter: null,
        frtAttackerIds: [attacker],
      );
      RivalService.applyFrtFeud(r, incoming: outcome, blockAnchor: base);

      final blamed = RivalService.attributedRivalId(r, attacker, base);
      expect(r.frtFeudUntilWeekById.keys, [blamed]);
      expect(
        r.frtFeudUntilWeekById[blamed],
        RivalService.weekIndexOf(base) + EconomyBalance.frtFeudWeeks,
      );
    });

    test('unentdeckte FRT-Angriffe erzeugen keine Fehde', () {
      final r = restaurant(anchor: base);
      final attacker = RivalService.rosterOf(r.district).first.id;
      final outcome = IncomingSabotageOutcome(
        blockAnchor: base,
        attackerIds: [attacker],
        detectedIds: const [],
        detectionPercent: 0,
        counter: null,
        frtAttackerIds: [attacker],
      );
      RivalService.applyFrtFeud(r, incoming: outcome, blockAnchor: base);
      expect(r.frtFeudUntilWeekById, isEmpty);
    });

    test('ohne FRT-Angriff passiert nichts', () {
      final r = restaurant(anchor: base);
      final attacker = RivalService.rosterOf(r.district).first.id;
      final outcome = IncomingSabotageOutcome(
        blockAnchor: base,
        attackerIds: [attacker],
        detectedIds: [attacker],
        detectionPercent: 100,
        counter: null,
      );
      RivalService.applyFrtFeud(r, incoming: outcome, blockAnchor: base);
      expect(r.frtFeudUntilWeekById, isEmpty);
      RivalService.applyFrtFeud(r, incoming: null, blockAnchor: base);
      expect(r.frtFeudUntilWeekById, isEmpty);
    });

    test('die Fehde stimmt den Rivalen in der Rangliste feindlicher', () {
      const playerPp = 50;
      const week = 5;
      final plain = restaurant(anchor: base);
      // Einen Rivalen wählen, der in der Rangliste **sichtbar** ist
      // (aktiv oder pleite) – nur die erscheinen als Zeilen.
      final rivalId = RivalService.standings(
        plain,
        playerPp: playerPp,
        weekIndex: week,
      ).entries.firstWhere((e) => !e.isPlayer).id;
      final withFeud = restaurant(anchor: base, feuds: {rivalId: week});

      RivalStanding entryOf(RestaurantData r) => RivalService.standings(
        r,
        playerPp: playerPp,
        weekIndex: week,
      ).entries.firstWhere((e) => e.id == rivalId);

      final before = entryOf(plain);
      final after = entryOf(withFeud);
      expect(after.powerProjection, before.powerProjection);
      expect(
        after.stance,
        RivalService.escalateStance(before.stance!),
        reason: 'Fehde verschiebt die Haltung um genau eine Stufe',
      );
    });

    test('die Fehde verschiebt auch die Gefechts-Haltung (C2)', () {
      const playerPp = 50;
      final plain = restaurant(anchor: base);
      List<BattleRivalParticipant> participants(RestaurantData r) =>
          RivalService.battleParticipants(
            r,
            playerPp: playerPp,
            availableSpawns: 4,
          );
      // Die Fehde wird auf einen **tatsächlichen** Gefechtsteilnehmer gesetzt.
      final target = participants(plain).first;
      final week = RivalService.weekIndexOf(base);
      final withFeud = restaurant(
        anchor: base,
        feuds: {target.rivalId: week + 1},
      );

      final before = participants(plain).firstWhere(
        (p) => p.rivalId == target.rivalId,
      );
      final after = participants(withFeud).firstWhere(
        (p) => p.rivalId == target.rivalId,
      );
      expect(after.teamSize, before.teamSize);
      expect(after.stance, RivalService.escalateStance(before.stance));
    });

    test('der Tick schreibt eine aufgedeckte Fehl-Attribution fort', () {
      // Block suchen, in dem ein FRT-Angriff **aufgedeckt** wird (reine
      // Auflösung, ohne Tick – deterministisch und billig).
      final crew = shadinessCrew();
      DateTime? anchorWithDetectedFrt;
      for (var i = 0; i < 400 && anchorWithDetectedFrt == null; i++) {
        final anchor = base.add(Duration(days: 7 * i));
        final probe = restaurant(staff: crew, anchor: anchor);
        final outcome = RivalService.resolveIncomingSabotage(probe, anchor);
        if (outcome == null) continue;
        if (outcome.detectedIds.any(outcome.frtAttackerIds.contains)) {
          anchorWithDetectedFrt = anchor;
        }
      }
      expect(
        anchorWithDetectedFrt,
        isNotNull,
        reason: 'über 400 Blöcke muss eine aufgedeckte Fehl-Attribution auftreten',
      );
      final anchor = anchorWithDetectedFrt!;

      final r = restaurant(staff: crew, anchor: anchor);
      final result =
          GameClockService.catchUp(r, anchor.add(const Duration(days: 7)));
      expect(result.weeks, 1);
      expect(r.frtFeudUntilWeekById, isNotEmpty);
      final blamed = r.frtFeudUntilWeekById.keys.first;
      expect(
        r.frtFeudUntilWeekById[blamed],
        RivalService.weekIndexOf(anchor) + EconomyBalance.frtFeudWeeks,
      );
    });

    test('runCatchUp behält die Fehde im Spielstand (C2-Persistenz)', () {
      final crew = shadinessCrew();
      DateTime? anchorWithDetectedFrt;
      for (var i = 0; i < 400 && anchorWithDetectedFrt == null; i++) {
        final anchor = base.add(Duration(days: 7 * i));
        final probe = restaurant(staff: crew, anchor: anchor);
        final outcome = RivalService.resolveIncomingSabotage(probe, anchor);
        if (outcome != null && outcome.detectedIds.any(outcome.frtAttackerIds.contains)) {
          anchorWithDetectedFrt = anchor;
        }
      }
      final anchor = anchorWithDetectedFrt!;
      final profile = ObjectProfile();
      profile.loadFromData(oneRestaurant(staff: crew), restaurantId: 10);
      profile.lastSeenAt = anchor;
      profile.weekAnchorAt = anchor;

      profile.runCatchUp(anchor.add(const Duration(days: 7)));
      expect(profile.frtFeudUntilWeekById, isNotEmpty);
      // Und der Wert steht in der zu speichernden Fassung.
      expect(
        profile.toProfileData().restaurants.single.frtFeudUntilWeekById,
        profile.frtFeudUntilWeekById,
      );
    });
  });

  group('Q7b – offene FRT-Angriffe auf Rivalen', () {
    test('frtAttacksRival ist deterministisch und nur für Wochen ≥ 0', () {
      expect(
        RivalService.frtAttacksRival(7, 12),
        RivalService.frtAttacksRival(7, 12),
      );
      expect(RivalService.frtAttacksRival(7, -1), isFalse);
      expect(RivalService.frtAttackPpLoss(7, -1), 0);
    });

    test('ein angegriffener Rivale verliert genau die Angriffs-PP', () {
      // Eine Woche mit Angriff finden und den Zustand **aller** Kandidaten
      // prüfen (die Simulation führt auch nicht aktive Rivalen).
      int? attackedWeek;
      for (var w = 0; w <= 40 && attackedWeek == null; w++) {
        if (RivalService.frtAttackedRivalCount('Midtown', w) > 0) {
          attackedWeek = w;
        }
      }
      expect(attackedWeek, isNotNull);
      final week = attackedWeek!;
      const playerPp = 50;
      final sim = RivalService.simulateField(
        'Midtown',
        playerPp: playerPp,
        weekIndex: week,
      );
      var sawReduced = false;
      for (final state in sim.states) {
        if (!RivalService.frtAttacksRival(state.rival.id, week)) continue;
        final raw = RivalService.simulatedRivalPp(
          state.rival,
          playerPp: playerPp,
          weekIndex: week,
        );
        final loss = EconomyBalance.frtRivalAttackPpLoss.round();
        final floor = EconomyBalance.rivalPpBankruptThreshold;
        final expected = raw.round() - loss < floor && raw.round() >= floor
            ? floor
            : raw.round() - loss;
        expect(state.powerProjection, expected);
        expect(state.powerProjection, lessThanOrEqualTo(raw.round()));
        if (state.powerProjection < raw.round()) sawReduced = true;
      }
      expect(
        sawReduced,
        isTrue,
        reason: 'mindestens ein Rivale muss spürbar PP verlieren',
      );
    });

    test('nicht angegriffene Rivalen behalten ihre simulierte PP', () {
      const week = 9;
      const playerPp = 50;
      final standings = RivalService.standings(
        restaurant(anchor: base),
        playerPp: playerPp,
        weekIndex: week,
      );
      for (final entry in standings.entries.where((e) => !e.isPlayer)) {
        if (RivalService.frtAttacksRival(entry.id, week)) continue;
        final rival = RivalService.byId(
          RivalService.candidatePool('Midtown'),
          entry.id,
        )!;
        expect(
          entry.powerProjection,
          RivalService.simulatedRivalPp(
            rival,
            playerPp: playerPp,
            weekIndex: week,
          ).round(),
        );
      }
    });

    test('die FRT drückt keinen gesunden Rivalen unter die Pleite-Schwelle', () {
      for (var w = 0; w <= 40; w++) {
        final sim = RivalService.simulateField(
          'Midtown',
          playerPp: 60,
          weekIndex: w,
        );
        for (final state in sim.states) {
          if (state.powerProjection < EconomyBalance.rivalPpBankruptThreshold) {
            expect(
              state.insolvent,
              isTrue,
              reason: 'unter der Schwelle ⇒ Pleite-Kennzeichnung',
            );
          }
        }
      }
    });

    test('der Tick meldet die Zahl der offenen FRT-Angriffe', () {
      final anchor = base.add(const Duration(days: 35));
      final r = restaurant(anchor: anchor);
      final result =
          GameClockService.catchUp(r, anchor.add(const Duration(days: 7)));
      expect(
        result.frtRivalAttacks,
        RivalService.frtAttackedRivalCount(
          r.district,
          RivalService.weekIndexOf(anchor),
        ),
      );
    });
  });

  group('C2 – Befreiung eines verlorenen Stadtteils', () {
    test('reduceCorruption meldet die Befreiung (Q4-Hysterese)', () {
      final profile = ObjectProfile();
      profile.loadFromData(
        oneRestaurant(corruption: 100, districtLost: true),
        restaurantId: 10,
      );
      expect(profile.districtLost, isTrue);
      final liberated = profile.reduceCorruption(
        monstersKilled: 3,
        victory: true,
      );
      expect(liberated, isTrue);
      expect(profile.districtLost, isFalse);
      expect(profile.districtLostAt, isNull);
      // Die Befreiung liegt auf der Platte an.
      final slot = profile.toProfileData().restaurants.single;
      expect(slot.districtLost, isFalse);
      expect(
        slot.corruptionPercent,
        FrtService.reduce(100, monstersKilled: 3, victory: true),
      );
    });

    test('ein nicht verlorener Stadtteil bleibt nach dem Gefecht bespielbar',
        () {
      final profile = ObjectProfile();
      profile.loadFromData(
        oneRestaurant(corruption: 5),
        restaurantId: 10,
      );
      expect(profile.districtLost, isFalse);
      // Kein verlorener Stadtteil ⇒ keine „Befreiung“ zu melden (der Wert sinkt
      // aber sehr wohl).
      expect(profile.reduceCorruption(monstersKilled: 1), isFalse);
      expect(profile.districtLost, isFalse);
      expect(profile.corruptionPercent, lessThan(5));
    });

    test('ohne Wirkung (keine Kills, kein Sieg) gibt es keine Befreiung', () {
      final profile = ObjectProfile();
      profile.loadFromData(
        oneRestaurant(corruption: 100, districtLost: true),
        restaurantId: 10,
      );
      expect(profile.reduceCorruption(), isFalse);
      expect(profile.districtLost, isTrue);
    });
  });
}
