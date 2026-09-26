import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/management_feature.dart';
import 'package:tiled_warfare/models/management_role.dart';
import 'package:tiled_warfare/models/personality.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/models/staff_entry.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/game_clock_service.dart';
import 'package:tiled_warfare/services/management_feature_service.dart';
import 'package:tiled_warfare/services/rival_service.dart';
import 'package:tiled_warfare/services/staff_role_service.dart';

/// Tests der V13-Erweiterung: Rolle **Sicherheitschef** (passive Entdeckung
/// eingehender Rivalen-Sabotage) und Feature **„Rache ist Blutwurst“**
/// (reaktiver Gegenschlag) samt Minimal-Modul „Rivalen-Sabotage gegen den
/// Spieler“ (Kapitel 13).
void main() {
  final start = DateTime(2026, 1, 1);
  final intruder = RivalService.rosterOf('Midtown').first;

  StaffEntryData management(
    ManagementRole role, {
    int id = 1,
    String? activeFeature,
    DateTime? activatedAt,
    int? targetId,
    List<int>? teamIds,
  }) => StaffEntryData(
    id: id,
    name: role.name,
    kind: RoleKind.management,
    role: role.name,
    costPerWeek: EconomyBalance.managementRoleWagePerWeek[role] ?? 0,
    activeFeature: activeFeature,
    featureTargetId: targetId,
    featureActivatedAt: activatedAt,
    featureTeamIds: teamIds,
  );

  StaffData staff(int id, {int personalityId = 2, String status = 'ready'}) =>
      StaffData(
        name: 'M$id',
        imagePath: 'x.png',
        type: kRankApprentice,
        rank: kRankApprentice,
        id: id,
        personalityId: personalityId,
        levelValue: 3,
        vitalityCurrent: 50,
        moraleCurrent: 50,
        status: status,
      );

  RestaurantData restaurant({
    List<StaffEntryData> entries = const [],
    List<StaffData> staffList = const [],
    int budget = 20000,
    DateTime? anchor,
  }) => RestaurantData(
    id: 1,
    name: 'R',
    district: 'Midtown',
    budget: budget,
    lastSeenAt: anchor ?? start,
    weekAnchorAt: anchor ?? start,
    staffEntries: entries,
    staff: staffList,
  );

  /// Ø-`shadiness` der Test-Aufstellung (identische Rechnung wie der Dienst,
  /// hier bewusst unabhängig nachgerechnet).
  int expectedAverageShadiness(List<StaffData> staffList) {
    final values = [
      for (final s in staffList)
        if (s.personalityId >= 0)
          PersonalityTraits.forProfile(s.personalityId, s.id).shadiness,
    ];
    if (values.isEmpty) return 0;
    final sum = values.reduce((a, b) => a + b);
    return (sum / values.length).round().clamp(0, 100);
  }

  /// Erster Blockanker (ab [start]) ohne bzw. mit mindestens einem
  /// eingehenden Angriff.
  DateTime anchorWithAttack(RestaurantData r, {bool wantAttack = true}) {
    for (var i = 0; i < 200; i++) {
      final anchor = start.add(Duration(days: 7 * i));
      final has = RivalService.incomingAttackerIds(r, anchor).isNotEmpty;
      if (has == wantAttack) return anchor;
    }
    fail('kein Blockanker mit wantAttack=$wantAttack gefunden');
  }

  /// Erster Blockanker (ab [start]) mit mindestens einem **entdeckten** Angriff.
  DateTime anchorWithDetectedAttack(RestaurantData r) {
    for (var i = 0; i < 400; i++) {
      final anchor = start.add(Duration(days: 7 * i));
      if (RivalService.detectedAttackerIds(r, anchor).isNotEmpty) return anchor;
    }
    fail('kein Blockanker mit entdecktem Angriff gefunden');
  }

  /// Träger-ID des Sicherheitschefs, deren Gegenschlag im Block [anchor] gegen
  /// den ersten entdeckten Angreifer wie gewünscht ausgeht.
  int? chiefIdFor(
    DateTime anchor, {
    required bool wantSuccess,
    List<StaffEntryData> extra = const [],
    List<StaffData> staffList = const [],
  }) {
    for (var id = 1; id <= 64; id++) {
      final chief = management(
        ManagementRole.securityChief,
        id: id,
        activeFeature: ManagementFeature.counterSabotage.name,
        activatedAt: anchor,
      );
      final r = restaurant(
        entries: [chief, ...extra],
        staffList: staffList,
        anchor: anchor,
      );
      final detected = RivalService.detectedAttackerIds(r, anchor);
      if (detected.isEmpty) continue;
      final chance = RivalService.counterSabotageChancePercent(r, chief);
      final success = ManagementFeatureService.counterSabotageSucceeds(
        chief,
        anchor,
        detected.first,
        chancePercent: chance,
      );
      if (success == wantSuccess) return id;
    }
    return null;
  }

  StaffEntryData chief({
    required int id,
    DateTime? activatedAt,
    int? resolvedAtOffsetDays,
  }) {
    final entry = management(
      ManagementRole.securityChief,
      id: id,
      activeFeature: activatedAt == null
          ? null
          : ManagementFeature.counterSabotage.name,
      activatedAt: activatedAt,
    );
    if (activatedAt != null && resolvedAtOffsetDays != null) {
      entry.featureResolvedAt = activatedAt.add(
        Duration(days: resolvedAtOffsetDays),
      );
    }
    return entry;
  }

  /// Blockanker + Träger-ID, deren Gegenschlag wie gewünscht ausgeht
  /// (`key` = Anker, `value` = Träger-ID); `null`, wenn kein Fall gefunden wird.
  MapEntry<DateTime, int>? findCounterCase({
    required bool wantSuccess,
    List<StaffEntryData> extra = const [],
    List<StaffData> staffList = const [],
  }) {
    for (var i = 0; i < 60; i++) {
      final anchor = start.add(Duration(days: 7 * i));
      final id = chiefIdFor(
        anchor,
        wantSuccess: wantSuccess,
        extra: extra,
        staffList: staffList,
      );
      if (id != null) return MapEntry(anchor, id);
    }
    return null;
  }

  /// Rechnet einen Gegenschlag gegen den ersten entdeckten Angreifer ab und
  /// liefert die gebuchte Strafe (setzt einen Misserfolg voraus).
  int resolveFailure({
    required DateTime anchor,
    required int chiefId,
    required List<StaffData> staffList,
  }) {
    final r = restaurant(
      entries: [chief(id: chiefId, activatedAt: anchor)],
      staffList: staffList,
      anchor: anchor,
    );
    final detected = RivalService.detectedAttackerIds(r, anchor);
    expect(detected, isNotEmpty);
    final outcome = RivalService.resolveCounterSabotage(
      r,
      r.staffEntries.first,
      detected.first,
      now: anchor.add(EconomyBalance.weeklyTick),
    );
    expect(outcome.success, isFalse);
    return outcome.fine;
  }

  group('Sicherheitschef: Rolle, Lohn und passive Entdeckung', () {
    test(
      'Lohn 240 €, Feature „Rache ist Blutwurst“, kein Einkommens-Effekt',
      () {
        expect(
          EconomyBalance.managementRoleWagePerWeek[ManagementRole
              .securityChief],
          240,
        );
        expect(
          managementFeatureOf(ManagementRole.securityChief),
          ManagementFeature.counterSabotage,
        );
        for (final role in kAllManagementRoles) {
          expect(
            EconomyBalance.managementRoleWagePerWeek[role],
            isNotNull,
            reason: 'Fehlender Wochenlohn für $role',
          );
        }
        expect(
          StaffRoleService.managementIncomePercent([
            management(ManagementRole.securityChief),
          ]),
          0,
        );
      },
    );

    test('Kompetenz 1–4 skaliert die Entdeckung deterministisch', () {
      final staffList = [staff(11), staff(22)];
      final withoutChief = restaurant(staffList: staffList);
      expect(
        RivalService.incomingDetectionPercent(withoutChief),
        (expectedAverageShadiness(staffList) *
                EconomyBalance.incomingDetectionShadinessToPercent /
                100)
            .round()
            .clamp(0, 100),
      );
      expect(
        StaffRoleService.securityChiefDetectionBonusPercent(
          withoutChief.staffEntries,
        ),
        0,
      );

      for (final id in [1, 2, 3, 4, 5]) {
        final entry = management(ManagementRole.securityChief, id: id);
        final withChief = restaurant(entries: [entry], staffList: staffList);
        final competence = ManagementFeatureService.competenceOf(entry);
        expect(competence, greaterThanOrEqualTo(1));
        expect(
          competence,
          lessThanOrEqualTo(EconomyBalance.featureCompetenceMax),
        );
        final expected =
            ((expectedAverageShadiness(staffList) *
                            EconomyBalance.incomingDetectionShadinessToPercent /
                            100)
                        .round() +
                    competence *
                        EconomyBalance
                            .securityChiefDetectionBonusPercentPerCompetence)
                .clamp(0, 100);
        expect(
          RivalService.incomingDetectionPercent(withChief),
          expected,
          reason: 'Entdeckung mit Kompetenz $competence',
        );
      }
    });

    test('Ø-shadiness ignoriert Charaktere ohne Profil', () {
      final noProfile = restaurant(staffList: [staff(11, personalityId: -1)]);
      expect(RivalService.averageShadiness(noProfile), 0);
      expect(RivalService.incomingDetectionPercent(noProfile), 0);
      expect(RivalService.averageShadiness(restaurant()), 0);
    });
  });

  group('Eingehende Rivalen-Sabotage (Minimal-Modul V13)', () {
    test('Versuche sind deterministisch und treffen rund 20 % der Würfe', () {
      final r = restaurant();
      final roster = RivalService.rosterOf('Midtown');
      var attempts = 0;
      for (var i = 0; i < 200; i++) {
        final anchor = start.add(Duration(days: 7 * i));
        final first = RivalService.incomingAttackerIds(r, anchor);
        expect(
          RivalService.incomingAttackerIds(r, anchor),
          first,
          reason: 'gleicher Anker ⇒ gleiche Angreifer (V8)',
        );
        for (final rival in roster) {
          if (RivalService.incomingAttemptOccurs(rival.id, anchor)) attempts++;
        }
      }
      final rolls = 200 * roster.length;
      expect(attempts, greaterThan((rolls * 0.1).floor()));
      expect(attempts, lessThan((rolls * 0.3).ceil()));
    });

    test('Entdeckungswurf ist monoton im Prozentwert', () {
      for (var i = 0; i < 20; i++) {
        final anchor = start.add(Duration(days: 7 * i));
        for (final rival in RivalService.rosterOf('Midtown')) {
          expect(
            RivalService.incomingAttemptDetected(rival.id, anchor, 0),
            isFalse,
          );
          expect(
            RivalService.incomingAttemptDetected(rival.id, anchor, 100),
            isTrue,
          );
        }
      }
    });

    test('ohne Angriff ist nichts zu buchen', () {
      final r = restaurant(staffList: [staff(11)]);
      final anchor = anchorWithAttack(r, wantAttack: false);
      expect(RivalService.incomingAttackerIds(r, anchor), isEmpty);
      expect(RivalService.detectedAttackerIds(r, anchor), isEmpty);
      expect(RivalService.resolveIncomingSabotage(r, anchor), isNull);
    });

    test('ohne Sicherheitschef gibt es keinen Gegenschlag', () {
      final r = restaurant(staffList: [staff(11), staff(22)]);
      final anchor = anchorWithDetectedAttack(r);
      final outcome = RivalService.resolveIncomingSabotage(
        r,
        anchor,
        now: anchor.add(EconomyBalance.weeklyTick),
      );
      expect(outcome, isNotNull);
      expect(outcome!.detected, isTrue);
      expect(outcome.counter, isNull);
      expect(r.sabotageTargetId, isNull);
      expect(r.sabotageAppliedUntil, isNull);
    });

    test('der Angreifer wird nur bei Entdeckung namentlich bekannt', () {
      final entries = [chief(id: 3, activatedAt: start)];
      final r = restaurant(entries: entries, staffList: [staff(11), staff(22)]);
      final anchor = anchorWithDetectedAttack(r);
      final outcome = RivalService.resolveIncomingSabotage(r, anchor)!;
      expect(outcome.blockAnchor, anchor);
      expect(outcome.attackerIds, RivalService.incomingAttackerIds(r, anchor));
      expect(outcome.detectedIds, isNotEmpty);
      expect(
        outcome.detectedIds.every(outcome.attackerIds.contains),
        isTrue,
        reason: 'entdeckte Angreifer sind Teilmenge der Angreifer',
      );
      expect(
        outcome.detectionPercent,
        RivalService.incomingDetectionPercent(r),
      );
    });
  });

  group('Aktivierung und Gegenschlag (Rache ist Blutwurst)', () {
    ObjectProfile profileWith({
      List<StaffEntryData> entries = const [],
      List<StaffData> staffList = const [],
      int budget = 20000,
    }) {
      final profile = ObjectProfile();
      profile.loadFromData(
        ProfileData(
          id: 1,
          name: 'P',
          creationDate: start,
          restaurants: [
            RestaurantData(
              id: 1,
              name: 'R',
              district: 'Midtown',
              budget: budget,
              lastSeenAt: start,
              weekAnchorAt: start,
              staff: staffList,
              staffEntries: entries,
            ),
          ],
        ),
        restaurantId: 1,
      );
      return profile;
    }

    test('kostet 1000 € und braucht einen freien Sicherheitschef', () {
      final withoutChief = profileWith(staffList: [staff(11)]);
      expect(
        withoutChief.activateUntargetedFeature(
          ManagementFeature.counterSabotage,
          now: start,
        ),
        isFalse,
      );
      expect(withoutChief.budget, 20000);

      final profile = profileWith(
        entries: [
          chief(id: 3),
          management(ManagementRole.chefSecretary, id: 9),
        ],
        staffList: [staff(11)],
      );
      expect(
        profile.managementFeatureActivationCost(
          ManagementFeature.counterSabotage,
        ),
        EconomyBalance.counterSabotageCost,
      );
      expect(
        profile.activateUntargetedFeature(
          ManagementFeature.counterSabotage,
          now: start,
        ),
        isTrue,
      );
      expect(profile.budget, 20000 - EconomyBalance.counterSabotageCost);
      expect(
        profile.managementFeatureIsActive(
          ManagementFeature.counterSabotage,
          now: start,
        ),
        isTrue,
      );
      // Ein zweites Feature läuft nicht parallel in derselben Träger-Zeile.
      expect(
        profile.activateUntargetedFeature(
          ManagementFeature.organisationIsEverything,
          now: start,
        ),
        isFalse,
      );
    });

    test('Fenster, Bereitschaft und Kompetenz-Grenzen', () {
      final leader = chief(id: 3, activatedAt: start);
      expect(ManagementFeatureService.competenceOf(leader), 4);
      expect(
        ManagementFeatureService.activeDurationOf(leader),
        EconomyBalance.counterSabotageActiveDuration,
      );
      expect(
        ManagementFeatureService.aftermathDurationOf(leader),
        EconomyBalance.counterSabotageAftermathDuration,
      );
      expect(
        ManagementFeatureService.activeEndOf(leader),
        start.add(EconomyBalance.weeklyTick),
      );
      expect(
        ManagementFeatureService.counterSabotageTeamLimit(leader),
        4 * EconomyBalance.counterSabotageTeamPerCompetence,
      );
      expect(
        ManagementFeatureService.fixedCostOf(ManagementFeature.counterSabotage),
        EconomyBalance.counterSabotageCost,
      );
      expect(
        ManagementFeatureService.isArmed(
          [leader],
          ManagementFeature.counterSabotage,
          start,
        ),
        isTrue,
      );
      leader.featureResolvedAt = start.add(EconomyBalance.dailyTick);
      expect(
        ManagementFeatureService.isArmed(
          [leader],
          ManagementFeature.counterSabotage,
          start,
        ),
        isFalse,
        reason: 'ausgeführt ⇒ nicht mehr bereit',
      );
      expect(
        ManagementFeatureService.isActive(
          [leader],
          ManagementFeature.counterSabotage,
          start,
        ),
        isTrue,
        reason: 'das Fenster läuft weiter',
      );
    });

    test('Mannschaft: die shadiness-stärksten einsatzfähigen Charaktere', () {
      final members = [
        staff(11, personalityId: 1),
        staff(22, personalityId: 2),
        staff(33, personalityId: 3),
        staff(44, personalityId: 4),
        staff(55, personalityId: 5),
      ];
      final entries = [chief(id: 3, activatedAt: start)];
      final r = restaurant(
        entries: entries,
        staffList: [
          ...members,
          staff(66, personalityId: 6, status: 'dead'),
          staff(77, personalityId: -1),
        ],
      );
      final sorted = [...members]
        ..sort((a, b) {
          final byShadiness =
              PersonalityTraits.forProfile(
                b.personalityId,
                b.id,
              ).shadiness.compareTo(
                PersonalityTraits.forProfile(a.personalityId, a.id).shadiness,
              );
          return byShadiness != 0 ? byShadiness : a.id.compareTo(b.id);
        });
      final limit = ManagementFeatureService.counterSabotageTeamLimit(
        entries.first,
      );
      expect(limit, 4);
      expect(
        RivalService.counterSabotageCrewIds(r),
        [for (final member in sorted.take(limit)) member.id],
        reason: 'stärkste shadiness zuerst, tote/Profillose ausgenommen',
      );
      expect(
        RivalService.counterSabotageCrewIds(restaurant(staffList: members)),
        isEmpty,
        reason: 'ohne Träger keine Mannschaft',
      );
    });

    test('Chance: mit Chefsekretärin führt sie, sonst die Mannschaft', () {
      final staffList = [
        staff(11, personalityId: 1),
        staff(22, personalityId: 2),
      ];
      final shadiness = {
        for (final member in staffList)
          member.id: PersonalityTraits.forProfile(
            member.personalityId,
            member.id,
          ).shadiness,
      };
      final secretary = management(ManagementRole.chefSecretary, id: 2);
      final withSecretary = restaurant(
        entries: [
          chief(id: 3, activatedAt: start),
          secretary,
        ],
        staffList: staffList,
      );
      expect(
        RivalService.counterSabotageChancePercent(
          withSecretary,
          withSecretary.staffEntries.first,
        ),
        ManagementFeatureService.sabotageSuccessPercentFor(secretary),
      );

      final busySecretary = management(
        ManagementRole.chefSecretary,
        id: 2,
        activeFeature: ManagementFeature.sabotage.name,
        activatedAt: start,
        targetId: intruder.id,
      );
      final withoutSecretary = restaurant(
        entries: [chief(id: 3, activatedAt: start)],
        staffList: staffList,
      );
      final leader = withoutSecretary.staffEntries.first;
      final crew = RivalService.counterSabotageCrewIds(withoutSecretary);
      expect(crew, isNotEmpty);
      final expected =
          ManagementFeatureService.counterSabotageSuccessPercentFor(leader) +
          ManagementFeatureService.shadinessBonusPercent(crew, shadiness);
      expect(
        RivalService.counterSabotageChancePercent(withoutSecretary, leader),
        expected,
      );
      expect(
        RivalService.counterSabotageChancePercent(
          restaurant(
            entries: [
              chief(id: 3, activatedAt: start),
              busySecretary,
            ],
            staffList: staffList,
          ),
          leader,
        ),
        expected,
        reason: 'beschäftigte Sekretärin ⇒ Mannschaft übernimmt',
      );
    });

    test('Misserfolg: die Strafe nimmt der Sicherheitschef auf sich', () {
      final staffList = [
        staff(11, personalityId: 1),
        staff(22, personalityId: 2),
      ];
      final found = findCounterCase(wantSuccess: false, staffList: staffList);
      expect(found, isNotNull, reason: 'kein Misserfolgs-Fall gefunden');
      expect(
        resolveFailure(
          anchor: found!.key,
          chiefId: found.value,
          staffList: staffList,
        ),
        EconomyBalance.counterSabotageFailureFine,
        reason: 'ohne Rechtsanwalt bleibt die Strafe ungemindert',
      );
    });

    test('automatischer Winkelzug mindert die Strafe des Gegenschlags', () {
      final lawyer = management(ManagementRole.lawyer, id: 3); // Kompetenz 4
      expect(
        StaffRoleService.counterSabotagePenaltyReductionPercent([
          lawyer,
        ], now: start),
        100,
        reason: 'Rechtsanwalt (25 %) + ausgelöster Winkelzug (100 %)',
      );
      expect(
        StaffRoleService.reducedCounterPenalty([lawyer], 1500, now: start),
        0,
      );
      expect(StaffRoleService.reducedPenalty([lawyer], 1500, now: start), 1125);
      expect(
        lawyer.activeFeature,
        isNull,
        reason: 'der Winkelzug wird nur mitgedacht, nicht gestartet',
      );
      expect(
        StaffRoleService.counterSabotagePenaltyReductionPercent(
          const [],
          now: start,
        ),
        0,
      );
      expect(
        StaffRoleService.reducedCounterPenalty(const [], 1500, now: start),
        1500,
      );
      // Ein bereits laufender Winkelzug wird nicht doppelt gezählt.
      final activeLawyer = management(
        ManagementRole.lawyer,
        id: 3,
        activeFeature: ManagementFeature.legalTrick.name,
        activatedAt: start,
      );
      expect(
        StaffRoleService.counterSabotagePenaltyReductionPercent([
          activeLawyer,
        ], now: start),
        100,
      );
    });

    test(
      'Erfolg: Wirkungsfenster gegen den Angreifer, Mannschaft erschöpft',
      () {
        final staffList = [
          staff(11, personalityId: 1),
          staff(22, personalityId: 2),
        ];
        final found = findCounterCase(wantSuccess: true, staffList: staffList);
        expect(found, isNotNull, reason: 'kein Erfolgs-Fall gefunden');
        final anchor = found!.key;
        final r = restaurant(
          entries: [chief(id: found.value, activatedAt: anchor)],
          staffList: staffList,
          anchor: anchor,
        );
        final detected = RivalService.detectedAttackerIds(r, anchor);
        expect(detected, isNotEmpty);
        final leader = r.staffEntries.first;
        final at = anchor.add(EconomyBalance.weeklyTick);
        final outcome = RivalService.resolveCounterSabotage(
          r,
          leader,
          detected.first,
          now: at,
        );
        expect(outcome.success, isTrue);
        expect(outcome.grossFine, 0);
        expect(r.sabotageTargetId, detected.first);
        expect(
          r.sabotageAppliedUntil,
          at.add(EconomyBalance.sabotageEffectDuration),
        );
        expect(
          RivalService.sabotageIncomeBonusPercent(r, at),
          EconomyBalance.sabotageIncomeBonusPercent,
        );
        expect(leader.featureResolvedAt, at);

        final crew = RivalService.counterSabotageCrewIds(r);
        expect(crew, isNotEmpty);
        final perMember = ManagementFeatureService.sabotageExhaustionPerMember(
          crew.length + 1,
        );
        for (final member in r.staff) {
          final drained = crew.contains(member.id);
          expect(member.vitalityCurrent, drained ? 50 - perMember : 50);
          expect(member.moraleCurrent, drained ? 50 - perMember : 50);
        }
      },
    );

    test('nur ein Gegenschlag je scharf geschaltetem Fenster', () {
      final staffList = [
        staff(11, personalityId: 1),
        staff(22, personalityId: 2),
      ];
      final found = findCounterCase(wantSuccess: true, staffList: staffList);
      expect(found, isNotNull);
      final anchor = found!.key;
      final r = restaurant(
        entries: [chief(id: found.value, activatedAt: anchor)],
        staffList: staffList,
        anchor: anchor,
      );
      final at = anchor.add(EconomyBalance.weeklyTick);
      final first = RivalService.resolveIncomingSabotage(r, anchor, now: at);
      expect(first!.counter, isNotNull);
      final second = RivalService.resolveIncomingSabotage(r, anchor, now: at);
      expect(
        second!.counter,
        isNull,
        reason: 'featureResolvedAt verhindert den zweiten Gegenschlag',
      );
      expect(second.detectedIds, first.detectedIds);
    });
  });

  group('Gegenschlag im Wochentick (V13)', () {
    final staffList = [
      staff(11, personalityId: 1),
      staff(22, personalityId: 2),
    ];

    test('Erfolg: der Angreifer wird getroffen, keine Strafe im Block', () {
      final found = findCounterCase(wantSuccess: true, staffList: staffList);
      expect(found, isNotNull);
      final anchor = found!.key;
      final end = anchor.add(const Duration(days: 7));
      final r = restaurant(
        entries: [chief(id: found.value, activatedAt: anchor)],
        staffList: staffList,
        anchor: anchor,
      );
      final detected = RivalService.detectedAttackerIds(r, anchor);
      expect(detected, isNotEmpty);

      final result = GameClockService.catchUp(r, end);
      expect(result.weeks, 1);
      expect(result.penaltyCosts, 0);
      expect(r.sabotageTargetId, detected.first);
      expect(
        r.sabotageAppliedUntil,
        end.add(EconomyBalance.sabotageEffectDuration),
      );

      // Der nächste Block liegt außerhalb des Fensters: kein zweiter Schlag.
      final nextBlock = anchor.add(const Duration(days: 14));
      final second = GameClockService.catchUp(r, nextBlock);
      expect(second.penaltyCosts, 0);
      expect(second.settlements.single.penaltyCosts, 0);
      expect(r.sabotageTargetId, detected.first);
      // Idempotent: derselbe `now` bucht nichts nach.
      expect(GameClockService.catchUp(r, nextBlock).penaltyCosts, 0);
    });

    test('Misserfolg: Strafe wird im Block gebucht (Rechtsanwalt mindert)', () {
      final lawyer = management(ManagementRole.lawyer, id: 9);
      final found = findCounterCase(
        wantSuccess: false,
        extra: [lawyer],
        staffList: staffList,
      );
      expect(found, isNotNull);
      final anchor = found!.key;
      final end = anchor.add(const Duration(days: 7));
      final entries = [chief(id: found.value, activatedAt: anchor), lawyer];
      final r = restaurant(
        entries: entries,
        staffList: staffList,
        anchor: anchor,
      );
      final expectedFine = StaffRoleService.reducedCounterPenalty(
        entries,
        EconomyBalance.counterSabotageFailureFine,
        now: end,
      );
      expect(expectedFine, lessThan(EconomyBalance.counterSabotageFailureFine));
      expect(expectedFine, greaterThan(0));

      final result = GameClockService.catchUp(r, end);
      expect(result.penaltyCosts, expectedFine);
      expect(result.settlements.single.penaltyCosts, expectedFine);
      expect(r.sabotageAppliedUntil, isNull);
      expect(r.staffEntries.first.featureResolvedAt, end);
      expect(lawyer.activeFeature, isNull);
      expect(GameClockService.catchUp(r, end).penaltyCosts, 0);
    });

    test('ohne Bereitschaft wird nichts gebucht', () {
      final found = findCounterCase(wantSuccess: true, staffList: staffList);
      expect(found, isNotNull);
      final anchor = found!.key;
      final r = restaurant(
        entries: [chief(id: found.value)],
        staffList: staffList,
        anchor: anchor,
      );
      expect(RivalService.detectedAttackerIds(r, anchor), isNotEmpty);
      final result = GameClockService.catchUp(
        r,
        anchor.add(const Duration(days: 7)),
      );
      expect(result.penaltyCosts, 0);
      expect(
        result.passiveIncome,
        greaterThan(0),
        reason: 'ohne scharfes Fenster bleibt das Einkommen positiv',
      );
      expect(r.sabotageTargetId, isNull);
      expect(r.sabotageAppliedUntil, isNull);
    });
  });

  group('Einkommens-Abschöpfung unentdeckter Angriffe (V13)', () {
    /// Blockanker (ab [start]) mit mindestens [min] Angreifern im Block.
    DateTime anchorWithAttackers(RestaurantData r, {int min = 1}) {
      for (var i = 0; i < 400; i++) {
        final anchor = start.add(Duration(days: 7 * i));
        if (RivalService.incomingAttackerIds(r, anchor).length >= min) {
          return anchor;
        }
      }
      fail('kein Blockanker mit mindestens $min Angreifern gefunden');
    }

    /// Aufstellung mit Einkommen, aber **ohne** Profil: `personalityId < 0`
    /// zählt nicht in die Ø-`shadiness` ⇒ Entdeckungsquote 0.
    final staffList = [
      staff(11, personalityId: -1),
      staff(22, personalityId: -1),
    ];

    test('je unentdecktem Angreifer −10 % Blockeinkommen (keine Strafe)', () {
      final probe = restaurant(staffList: staffList);
      expect(RivalService.incomingDetectionPercent(probe), 0);
      final anchor = anchorWithAttackers(probe);
      final attackers = RivalService.incomingAttackerIds(probe, anchor);
      final expectedPercent =
          (attackers.length *
                  EconomyBalance.incomingSabotageIncomePenaltyPercent)
              .clamp(0, EconomyBalance.incomingSabotageIncomePenaltyMaxPercent);
      expect(expectedPercent, greaterThan(0));

      final r = restaurant(staffList: staffList, anchor: anchor);
      final result = GameClockService.catchUp(
        r,
        anchor.add(const Duration(days: 7)),
      );
      final settlement = result.settlements.single;
      final gross = settlement.income + result.rivalSabotageLosses;
      expect(result.rivalSabotageLosses, greaterThan(0));
      expect(
        result.rivalSabotageLosses,
        (gross * expectedPercent / 100).round(),
        reason: 'Abschöpfung = Angreifer × 10 % des Brutto-Blockeinkommens',
      );
      expect(settlement.income, gross - result.rivalSabotageLosses);
      expect(result.passiveIncome, gross - result.rivalSabotageLosses);
      expect(result.penaltyCosts, 0, reason: 'Abschöpfung ist keine Strafe');
    });

    test('mehrere Angreifer stapeln sich höchstens bis 30 %', () {
      final probe = restaurant(staffList: staffList);
      final perAttacker = EconomyBalance.incomingSabotageIncomePenaltyPercent;
      final cap = EconomyBalance.incomingSabotageIncomePenaltyMaxPercent;
      final anchor = anchorWithAttackers(
        probe,
        min: (cap / perAttacker).ceil(),
      );
      final attackers = RivalService.incomingAttackerIds(probe, anchor);
      expect(
        attackers.length * perAttacker,
        greaterThanOrEqualTo(cap),
        reason: 'Deckel muss greifen (${attackers.length} Angreifer)',
      );

      final result = GameClockService.catchUp(
        restaurant(staffList: staffList, anchor: anchor),
        anchor.add(const Duration(days: 7)),
      );
      final settlement = result.settlements.single;
      final gross = settlement.income + result.rivalSabotageLosses;
      expect(
        result.rivalSabotageLosses,
        (gross * cap / 100).round(),
        reason: 'Deckel bei $cap % des Brutto-Blockeinkommens',
      );
    });

    test('vollständig entdeckte Angriffe schöpfen nichts ab', () {
      final staffList = [
        staff(11, personalityId: 1),
        staff(22, personalityId: 2),
      ];
      for (var id = 1; id <= 12; id++) {
        for (var i = 0; i < 60; i++) {
          final anchor = start.add(Duration(days: 7 * i));
          final probe = restaurant(
            entries: [chief(id: id)],
            staffList: staffList,
            anchor: anchor,
          );
          final attackers = RivalService.incomingAttackerIds(probe, anchor);
          if (attackers.isEmpty) continue;
          if (RivalService.detectedAttackerIds(probe, anchor).length !=
              attackers.length) {
            continue;
          }
          final result = GameClockService.catchUp(
            probe,
            anchor.add(const Duration(days: 7)),
          );
          expect(result.rivalSabotageLosses, 0);
          expect(result.settlements.single.income, greaterThan(0));
          return;
        }
      }
      fail('kein Block mit vollständiger Entdeckung gefunden');
    });

    test(
      'Konstanten: 10 % je Angreifer, Deckel 30 %, Determinismus je Anker',
      () {
        expect(EconomyBalance.incomingSabotageIncomePenaltyPercent, 10);
        expect(EconomyBalance.incomingSabotageIncomePenaltyMaxPercent, 30);
        // Derselbe Rivale/Block liefert stets dieselbe Abschöpfung.
        final r = restaurant();
        final anchor = anchorWithAttackers(r);
        final first = RivalService.resolveIncomingSabotage(r, anchor)!;
        final second = RivalService.resolveIncomingSabotage(r, anchor)!;
        expect(second.undetectedIds, first.undetectedIds);
        expect(second.undetectedCount, first.undetectedCount);
        expect(first.undetectedCount, first.attackerIds.length);
      },
    );
  });
}
