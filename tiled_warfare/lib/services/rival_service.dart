import 'package:random_name_generator/random_name_generator.dart';
import 'package:tiled_warfare/models/management_feature.dart';
import 'package:tiled_warfare/models/management_role.dart';
import 'package:tiled_warfare/models/personality.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/models/rival_restaurant.dart';
import 'package:tiled_warfare/models/staff_entry.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/management_feature_service.dart';
import 'package:tiled_warfare/services/staff_role_service.dart';
import 'package:tiled_warfare/utils/crc32.dart';

/// Ergebnis einer aufgelösten Sabotage (`11a` E14 / Kapitel 13).
class SabotageOutcome {
  /// Getroffenes Rivalen-Restaurant.
  final int rivalId;

  /// `true`, wenn die Sabotage unbemerkt blieb.
  final bool success;

  /// Strafe vor der Minderung durch den Rechtsanwalt (Euro).
  final int grossFine;

  /// Tatsächlich abgebuchte Strafe (nach `StaffRoleService.reducedPenalty`).
  final int fine;

  /// Ende des Wirkungsfensters (nur bei Erfolg).
  final DateTime? effectUntil;

  const SabotageOutcome({
    required this.rivalId,
    required this.success,
    required this.grossFine,
    required this.fine,
    required this.effectUntil,
  });
}

/// Ergebnis der **eingehenden** Rivalen-Sabotage eines vollen Wochenblocks
/// (Minimal-Modul V13, Kapitel 13).
///
/// [attackerIds] sind alle Rivalen, die in diesem Block einen deterministischen
/// Sabotageversuch gestartet haben; [detectedIds] die davon **entdeckten**
/// Angreifer (nur deren Identität ist dem Spieler bekannt). [counter] ist der
/// Gegenschlag des Sicherheitschefs (nur wenn das Feature in diesem Block scharf
/// geschaltet war und mindestens ein Angriff entdeckt wurde).
class IncomingSabotageOutcome {
  /// Anker des abgerechneten Blocks (`weekAnchorAt` des Blockstarts).
  final DateTime blockAnchor;

  /// Rivalen-IDs aller Angreifer des Blocks (Roster-Reihenfolge).
  final List<int> attackerIds;

  /// Rivalen-IDs der **entdeckten** Angreifer (Roster-Reihenfolge).
  final List<int> detectedIds;

  /// Entdeckungswahrscheinlichkeit (Prozent) des Blocks – Ø-`shadiness` des
  /// Personals plus Kompetenz-Bonus des Sicherheitschefs.
  final int detectionPercent;

  /// Gegenschlag des Sicherheitschefs (oder `null`).
  final SabotageOutcome? counter;

  const IncomingSabotageOutcome({
    required this.blockAnchor,
    required this.attackerIds,
    required this.detectedIds,
    required this.detectionPercent,
    required this.counter,
  });

  /// `true`, wenn mindestens ein Angriff entdeckt wurde.
  bool get detected => detectedIds.isNotEmpty;

  /// Rivalen-IDs der **unentdeckt** gebliebenen Angreifer (Roster-Reihenfolge) –
  /// sie bleiben dem Spieler unbekannt und schöpfen Blockeinkommen ab.
  List<int> get undetectedIds => [
    for (final id in attackerIds)
      if (!detectedIds.contains(id)) id,
  ];

  /// Anzahl der unentdeckt gebliebenen Angreifer.
  int get undetectedCount => undetectedIds.length;
}

/// Rivalen-Restaurants des Stadtteils – **Minimal-Modul** des Kapitels 13
/// (`13_Gegner_Restaurants.md`), V11.
///
/// Der Roster ist eine **reine, deterministische Funktion** aus Stadtteil und
/// Rivalen-Index (ID/`personalityId` per CRC32, Anzahl aus dem Prestige-Tier) –
/// kein Zufall im Catch-up (V8-Idempotenz). Nur die **Namen** stammen aus dem
/// Namensgenerator (`random_name_generator`, wie beim Personal) und werden je
/// Stadtteil einmalig erzeugt und zwischengespeichert, damit die UI innerhalb
/// einer Sitzung stabil bleibt.
///
/// Die Rivalen rechnen außerdem **selbst** ab: Je vollem Wochenblock wird
/// deterministisch gewürfelt, ob ein Rivale einen Sabotageversuch gegen den
/// Spieler unternimmt, und ob dieser entdeckt wird (Minimal-Modul V13). Der
/// passive **Sicherheitschef** hebt die Entdeckungswahrscheinlichkeit; das
/// Feature **„Rache ist Blutwurst“** beantwortet einen im eigenen Fenster
/// entdeckten Angriff mit einem Gegenschlag (`resolveIncomingSabotage`).
/// Die **wirtschaftliche Folge** eines *unentdeckten* Angriffs ist der
/// Einkommens-Malus `incomingSabotageIncomePenaltyPercent` je unentdecktem
/// Angreifer (gedeckelt über `incomingSabotageIncomePenaltyMaxPercent`), den
/// `GameClockService.catchUp` am Blockende vom Blockeinkommen abzieht.
///
/// Nicht Teil dieses Minimal-Moduls: Power Projection/Rangliste, Gefechts-
/// teilnahme und Rivalen-Simulation (Kapitel 13 → „Handlungen (Prototyp)“
/// Schritte 2–3).
class RivalService {
  RivalService._();

  /// Zwischenspeicher der Roster je Stadtteil (Namensstabilität, s. o.).
  static final Map<String, List<RivalRestaurant>> _cache = {};

  /// Rivalen-Anzahl eines Stadtteils aus dem Prestige-Tier (S–D).
  static int countFor(String? district) {
    final prestige = EconomyBalance.districtPrestigeFor(district);
    final int count;
    if (prestige >= EconomyBalance.rivalCountPrestigeS) {
      count = EconomyBalance.rivalCountS;
    } else if (prestige >= EconomyBalance.rivalCountPrestigeA) {
      count = EconomyBalance.rivalCountA;
    } else if (prestige >= EconomyBalance.rivalCountPrestigeB) {
      count = EconomyBalance.rivalCountB;
    } else if (prestige >= EconomyBalance.rivalCountPrestigeC) {
      count = EconomyBalance.rivalCountC;
    } else {
      count = EconomyBalance.rivalCountD;
    }
    return count.clamp(
      EconomyBalance.rivalCountMin,
      EconomyBalance.rivalCountMax,
    );
  }

  /// Deterministischer Roster des Stadtteils [district] (Anzeige-Reihenfolge).
  static List<RivalRestaurant> rosterOf(String? district) {
    final key = district ?? '';
    final cached = _cache[key];
    if (cached != null) return cached;
    final prestige = EconomyBalance.districtPrestigeFor(district);
    final zone = EconomyBalance.rivalNameZone;
    final roster = <RivalRestaurant>[
      for (var index = 0; index < countFor(district); index++)
        RivalRestaurant(
          id: CRC32.compute('rival:$key:$index'),
          name: RandomNames(zone).fullName(),
          district: key,
          personalityId: CRC32.compute('rival-personality:$key:$index') %
              EnneagramProfile.all.length,
          basePrestige: prestige,
        ),
    ];
    _cache[key] = roster;
    return roster;
  }

  /// Rivale mit der [id] (oder `null`).
  static RivalRestaurant? byId(Iterable<RivalRestaurant> roster, int? id) {
    if (id == null) return null;
    for (final rival in roster) {
      if (rival.id == id) return rival;
    }
    return null;
  }

  /// `true`, wenn `restaurant` zum Zeitpunkt [now] von einer erfolgreichen
  /// Sabotage profitiert (Einkommens-Fenster aktiv).
  static bool sabotageBonusActive(RestaurantData restaurant, DateTime now) {
    final until = restaurant.sabotageAppliedUntil;
    return until != null && now.isBefore(until);
  }

  /// Einkommens-Zuschlag (Prozent) aus einer laufenden Sabotage (E14).
  static int sabotageIncomeBonusPercent(
    RestaurantData restaurant,
    DateTime now,
  ) => sabotageBonusActive(restaurant, now)
      ? EconomyBalance.sabotageIncomeBonusPercent
      : 0;

  /// Erfolgswahrscheinlichkeit (Prozent) einer Sabotage **inklusive** des
  /// `shadiness`-Boni der Mannschaft (V12).
  ///
  /// Ohne aktives „Alle Räder …“ ist die Mannschaft leer und der Bonus `0` –
  /// die Chance entspricht dann unverändert `11a` E14.
  static int sabotageChancePercent(
    RestaurantData restaurant,
    StaffEntryData entry,
    DateTime now,
  ) {
    final teamIds = ManagementFeatureService.unionWorkersTeamIds(
      restaurant.staffEntries,
      now,
    );
    return ManagementFeatureService.sabotageSuccessPercentFor(entry) +
        ManagementFeatureService.shadinessBonusPercent(
          teamIds,
          _shadinessById(restaurant),
        );
  }

  /// `shadiness` aller Charaktere des Restaurants (ID → Wert); Charaktere ohne
  /// Persönlichkeits-Profil werden ausgelassen (V12).
  static Map<int, int> _shadinessById(RestaurantData restaurant) {
    final result = <int, int>{};
    for (final s in restaurant.staff) {
      if (s.personalityId < 0) continue;
      result[s.id] = PersonalityTraits.forProfile(
        s.personalityId,
        s.id,
      ).shadiness;
    }
    return result;
  }

  /// Belastet die Sabotage-Mannschaft mit der (gemittelten) Erschöpfung des
  /// Auftrags (V12: Vitalität **und** Moral).
  ///
  /// Die Mannschaftsgröße ist `1 + Anzahl der Mitglieder` (der Träger zählt
  /// mit); die Gesamtlast `sabotageExhaustionPerMission` wird darauf gemittelt.
  static void _applySabotageExhaustion(
    RestaurantData restaurant,
    List<int> teamIds,
  ) {
    if (teamIds.isEmpty) return;
    final perMember = ManagementFeatureService.sabotageExhaustionPerMember(
      teamIds.length + 1,
    );
    if (perMember <= 0) return;
    for (final s in restaurant.staff) {
      if (!teamIds.contains(s.id)) continue;
      if (s.vitalityCurrent != null) {
        s.vitalityCurrent = (s.vitalityCurrent! - perMember).clamp(
          EconomyBalance.resourceMin,
          EconomyBalance.resourceMax,
        );
      }
      if (s.moraleCurrent != null) {
        s.moraleCurrent = (s.moraleCurrent! - perMember).clamp(
          EconomyBalance.resourceMin,
          EconomyBalance.resourceMax,
        );
      }
    }
  }

  /// Löst eine fällige Sabotage des Trägers [entry] auf und bucht die Folgen.
  ///
  /// **Erfolg:** Der Rivale ist für `sabotageEffectDuration` sabotiert
  /// (`restaurant.sabotageTargetId`/`sabotageAppliedUntil` → Prestige-Malus in
  /// `RivalRestaurant.sabotagedPrestige`, Einkommens-Bonus im Catch-up).
  /// **Misserfolg:** Der Spieler zahlt `sabotageCaughtFine`, gemindert um die
  /// Strafen-Minderung (`StaffRoleService.reducedPenalty` – Rechtsanwalt-Passiv
  /// **plus** aktiver Winkelzug).
  ///
  /// Idempotent über `entry.featureResolvedAt`: eine Aktivierung wird genau
  /// einmal abgerechnet (V8).
  ///
  /// V12 („Alle Räder …“): Ist das Feature aktiv, besteht die Mannschaft aus
  /// dem Träger plus den gewählten Mitgliedern (`featureTeamIds`); die
  /// gemittelte `shadiness` hebt die Chance, je Mitglied gibt es einen Reroll,
  /// und die Erschöpfung des Auftrags wird auf die Mannschaft verteilt.
  ///
  /// Die Auflösung verändert **nicht** `restaurant.budget`: Die Strafe wird als
  /// [SabotageOutcome.fine] gemeldet und von der aufrufenden Tick-Schleife im
  /// dortigen Wochenbudget gebucht (eine Quelle der Wahrheit).
  static SabotageOutcome? resolveSabotage(
    RestaurantData restaurant,
    StaffEntryData entry,
    DateTime now,
  ) {
    if (managementFeatureFromName(entry.activeFeature) !=
        ManagementFeature.sabotage) {
      return null;
    }
    final rivalId = entry.featureTargetId;
    if (rivalId == null) return null;
    if (!ManagementFeatureService.isResolutionDue(entry, now)) return null;

    final resolvedAt = ManagementFeatureService.activeEndOf(entry) ?? now;
    final teamIds = ManagementFeatureService.unionWorkersTeamIds(
      restaurant.staffEntries,
      now,
    );
    final attempts = ManagementFeatureService.sabotageAttempts(
      restaurant.staffEntries,
      now,
    );
    final chance = sabotageChancePercent(restaurant, entry, now);
    // Erschöpfung des Auftrags wird zusammen mit der Auflösung gebucht.
    _applySabotageExhaustion(restaurant, teamIds);
    entry.featureResolvedAt = resolvedAt;
    if (ManagementFeatureService.sabotageSucceeds(
      entry,
      rivalId,
      attempts: attempts,
      chancePercent: chance,
    )) {
      restaurant.sabotageTargetId = rivalId;
      restaurant.sabotageAppliedUntil = resolvedAt.add(
        EconomyBalance.sabotageEffectDuration,
      );
      return SabotageOutcome(
        rivalId: rivalId,
        success: true,
        grossFine: 0,
        fine: 0,
        effectUntil: restaurant.sabotageAppliedUntil,
      );
    }

    final grossFine = EconomyBalance.sabotageCaughtFine;
    final fine = StaffRoleService.reducedPenalty(
      restaurant.staffEntries,
      grossFine,
      now: now,
    );
    restaurant.sabotageTargetId = null;
    restaurant.sabotageAppliedUntil = null;
    return SabotageOutcome(
      rivalId: rivalId,
      success: false,
      grossFine: grossFine,
      fine: fine,
      effectUntil: null,
    );
  }

  // ── Eingehende Rivalen-Sabotage & Gegenschlag (V13, Kapitel 13) ─────────

  /// `true`, wenn der Rivale [rivalId] im Block mit dem Anker [blockAnchor]
  /// einen Sabotageversuch gegen den Spieler unternimmt.
  ///
  /// Deterministisch (`CRC32('rival-attack:<anchor>:<rivalId>')`) – kein Zufall
  /// im Catch-up (V8-Idempotenz), gleiche Werte bei jedem Laden.
  static bool incomingAttemptOccurs(int rivalId, DateTime blockAnchor) {
    final stamp = blockAnchor.toIso8601String();
    return CRC32.compute('rival-attack:$stamp:$rivalId').abs() % 100 <
        EconomyBalance.incomingSabotageChanceBasePercent;
  }

  /// `true`, wenn der Versuch des Rivalen [rivalId] im Block [blockAnchor]
  /// **entdeckt** wird (Wurf `< detectionPercent`).
  static bool incomingAttemptDetected(
    int rivalId,
    DateTime blockAnchor,
    int detectionPercent,
  ) {
    final stamp = blockAnchor.toIso8601String();
    return CRC32.compute('rival-attack-detected:$stamp:$rivalId').abs() % 100 <
        detectionPercent;
  }

  /// Durchschnittliche `shadiness` des Kampfpersonals des Restaurants (0–100).
  ///
  /// Charaktere ohne Persönlichkeits-Profil (`personalityId < 0`) zählen nicht;
  /// ohne zählbares Personal ist der Wert `0` (schlechteste Entdeckung).
  static int averageShadiness(RestaurantData restaurant) {
    var sum = 0;
    var count = 0;
    for (final member in restaurant.staff) {
      if (member.personalityId < 0) continue;
      sum += PersonalityTraits.forProfile(
        member.personalityId,
        member.id,
      ).shadiness;
      count++;
    }
    if (count == 0) return 0;
    return (sum / count).round().clamp(0, 100);
  }

  /// Entdeckungswahrscheinlichkeit (Prozent) eines eingehenden
  /// Sabotageversuchs.
  ///
  /// Ø-`shadiness` des Personals × `incomingDetectionShadinessToPercent`/100
  /// plus Kompetenz-Bonus des passiven Sicherheitschefs
  /// (`securityChiefDetectionBonusPercentPerCompetence`), auf `100` gedeckelt.
  static int incomingDetectionPercent(RestaurantData restaurant) =>
      ((averageShadiness(restaurant) *
                      EconomyBalance.incomingDetectionShadinessToPercent /
                      100)
                  .round() +
              StaffRoleService.securityChiefDetectionBonusPercent(
                restaurant.staffEntries,
              ))
          .clamp(0, 100);

  /// Rivalen-IDs aller Angreifer des Blocks [blockAnchor] (Roster-Reihenfolge).
  static List<int> incomingAttackerIds(
    RestaurantData restaurant,
    DateTime blockAnchor,
  ) => [
    for (final rival in rosterOf(restaurant.district))
      if (incomingAttemptOccurs(rival.id, blockAnchor)) rival.id,
  ];

  /// Rivalen-IDs der **entdeckten** Angreifer des Blocks [blockAnchor].
  static List<int> detectedAttackerIds(
    RestaurantData restaurant,
    DateTime blockAnchor, {
    int? detectionPercent,
  }) {
    final percent = detectionPercent ?? incomingDetectionPercent(restaurant);
    return [
      for (final rivalId in incomingAttackerIds(restaurant, blockAnchor))
        if (incomingAttemptDetected(rivalId, blockAnchor, percent)) rivalId,
    ];
  }

  /// Der Ausführende des Gegenschlags: die angestellte **Chefsekretärin**, wenn
  /// sie gerade keine eigene Mission laufen hat (oder `null`).
  ///
  /// Ist sie im Einsatz, greift stattdessen die rekrutierte Mannschaft.
  static StaffEntryData? counterSabotageSecretary(RestaurantData restaurant) {
    for (final entry in restaurant.staffEntries) {
      if (entry.kind != RoleKind.management) continue;
      if (entry.role != ManagementRole.chefSecretary.name) continue;
      if (entry.activeFeature == null) return entry;
    }
    return null;
  }

  /// Deterministisch rekrutierte Mannschaft eines Gegenschlags (Charakter-IDs).
  ///
  /// Gewählt werden die `Kompetenz × counterSabotageTeamPerCompetence`
  /// **shadiness-stärksten** einsatzfähigen Charaktere; bei Gleichstand
  /// entscheidet die kleinere ID (stabil über Ladevorgänge).
  static List<int> counterSabotageCrewIds(RestaurantData restaurant) {
    final leader = ManagementFeatureService.ownerOf(
      restaurant.staffEntries,
      ManagementFeature.counterSabotage,
    );
    if (leader == null) return const [];
    final limit = ManagementFeatureService.counterSabotageTeamLimit(leader);
    if (limit <= 0) return const [];
    final candidates = restaurant.staff
        .where(
          (member) =>
              member.personalityId >= 0 &&
              !const {'dying', 'dead', 'overkilled'}.contains(member.status),
        )
        .toList();
    candidates.sort((a, b) {
      final byShadiness = PersonalityTraits.forProfile(b.personalityId, b.id)
          .shadiness
          .compareTo(
            PersonalityTraits.forProfile(a.personalityId, a.id).shadiness,
          );
      return byShadiness != 0 ? byShadiness : a.id.compareTo(b.id);
    });
    return [for (final member in candidates.take(limit)) member.id];
  }

  /// Erfolgswahrscheinlichkeit (Prozent) eines Gegenschlags des
  /// Sicherheitschefs [leader].
  ///
  /// Mit angestellter Chefsekretärin führt **sie** den Auftrag aus (Chance wie
  /// ihre eigene Sabotage); ohne sie führt der Sicherheitschef eine
  /// deterministisch rekrutierte Mannschaft, deren gemittelte `shadiness` die
  /// Chance hebt.
  static int counterSabotageChancePercent(
    RestaurantData restaurant,
    StaffEntryData leader,
  ) {
    final secretary = counterSabotageSecretary(restaurant);
    if (secretary != null) {
      return ManagementFeatureService.sabotageSuccessPercentFor(secretary);
    }
    return ManagementFeatureService.counterSabotageSuccessPercentFor(leader) +
        ManagementFeatureService.shadinessBonusPercent(
          counterSabotageCrewIds(restaurant),
          _shadinessById(restaurant),
        );
  }

  /// Löst den Gegenschlag des Sicherheitschefs [leader] gegen den entdeckten
  /// Angreifer [attackerId] auf.
  ///
  /// **Erfolg:** Der Angreifer wird wie bei einer eigenen Sabotage getroffen
  /// (`sabotageTargetId`/`sabotageAppliedUntil` ⇒ Prestige-Malus und
  /// Einkommens-Fenster). **Misserfolg:** Der Sicherheitschef „nimmt den Schaden
  /// auf sich“ – `counterSabotageFailureFine`, gemindert um die
  /// Strafen-Minderung (`StaffRoleService.reducedCounterPenalty`, inkl.
  /// automatisch ausgelöstem Winkelzug des Rechtsanwalts).
  ///
  /// Der Aufruf setzt `leader.featureResolvedAt` und ist damit über den
  /// Wochen-Tick **idempotent**: je scharfgeschaltetem Fenster gibt es genau
  /// einen Gegenschlag. Nur die rekrutierte Mannschaft wird erschöpft – läuft
  /// der Auftrag über die Chefsekretärin, trägt niemand körperliche Last.
  static SabotageOutcome resolveCounterSabotage(
    RestaurantData restaurant,
    StaffEntryData leader,
    int attackerId, {
    DateTime? now,
  }) {
    final at = now ?? leader.featureActivatedAt ?? DateTime.now();
    // Wurf-Anker ist die Aktivierung – stabil über Blöcke und Ladevorgänge.
    final anchor = leader.featureActivatedAt ?? at;
    final chance = counterSabotageChancePercent(restaurant, leader);
    final crewIds = counterSabotageSecretary(restaurant) == null
        ? counterSabotageCrewIds(restaurant)
        : const <int>[];
    final success = ManagementFeatureService.counterSabotageSucceeds(
      leader,
      anchor,
      attackerId,
      chancePercent: chance,
    );
    leader.featureResolvedAt = at;
    if (crewIds.isNotEmpty) _applySabotageExhaustion(restaurant, crewIds);
    if (success) {
      restaurant.sabotageTargetId = attackerId;
      restaurant.sabotageAppliedUntil = at.add(
        EconomyBalance.sabotageEffectDuration,
      );
      return SabotageOutcome(
        rivalId: attackerId,
        success: true,
        grossFine: 0,
        fine: 0,
        effectUntil: restaurant.sabotageAppliedUntil,
      );
    }
    final grossFine = EconomyBalance.counterSabotageFailureFine;
    final fine = StaffRoleService.reducedCounterPenalty(
      restaurant.staffEntries,
      grossFine,
      now: at,
    );
    return SabotageOutcome(
      rivalId: attackerId,
      success: false,
      grossFine: grossFine,
      fine: fine,
      effectUntil: null,
    );
  }

  /// Rechnet den **eingehenden** Sabotageblock des Ankers [blockAnchor] ab.
  ///
  /// 1. Je Rivale des Stadtteils fällt deterministisch, ob ein Versuch eingeht.
  /// 2. Je Versuch fällt deterministisch, ob er entdeckt wird.
  /// 3. Ist „Rache ist Blutwurst“ in diesem Block scharf geschaltet und wurde
  ///    mindestens ein Angriff entdeckt, folgt **höchstens ein** Gegenschlag
  ///    (gegen den ersten entdeckten Angreifer in Roster-Reihenfolge).
  ///
  /// Gibt `null` zurück, wenn es in diesem Block **keinen** Versuch gab – dann
  /// ist nichts zu buchen. Der Aufruf fasst `restaurant.budget` nicht an; die
  /// Strafe eines gescheiterten Gegenschlags wird als [SabotageOutcome.fine]
  /// gemeldet und von der Tick-Schleife im dortigen Wochenbudget gebucht (eine
  /// Quelle der Wahrheit, wie bei [resolveSabotage]).
  static IncomingSabotageOutcome? resolveIncomingSabotage(
    RestaurantData restaurant,
    DateTime blockAnchor, {
    DateTime? now,
  }) {
    final attackers = incomingAttackerIds(restaurant, blockAnchor);
    if (attackers.isEmpty) return null;
    final detection = incomingDetectionPercent(restaurant);
    final detected = [
      for (final rivalId in attackers)
        if (incomingAttemptDetected(rivalId, blockAnchor, detection)) rivalId,
    ];
    final at = now ?? blockAnchor;
    final leader = ManagementFeatureService.activeEntry(
      restaurant.staffEntries,
      ManagementFeature.counterSabotage,
      at,
    );
    SabotageOutcome? counter;
    if (leader != null &&
        leader.featureResolvedAt == null &&
        detected.isNotEmpty) {
      counter = resolveCounterSabotage(
        restaurant,
        leader,
        detected.first,
        now: at,
      );
    }
    return IncomingSabotageOutcome(
      blockAnchor: blockAnchor,
      attackerIds: attackers,
      detectedIds: detected,
      detectionPercent: detection,
      counter: counter,
    );
  }
}
