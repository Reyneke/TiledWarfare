import 'package:random_name_generator/random_name_generator.dart';
import 'package:tiled_warfare/models/management_feature.dart';
import 'package:tiled_warfare/models/management_role.dart';
import 'package:tiled_warfare/models/personality.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/models/rival_restaurant.dart';
import 'package:tiled_warfare/models/staff_entry.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/economy_service.dart';
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

  /// Rivalen-IDs, deren Angriff in Wahrheit ein **FRT-Angriff mit
  /// Fehl-Attribution** ist (Kapitel 14, Q6). Deterministische Teilmenge von
  /// [attackerIds]; dem Spieler bleibt die Wahrheit verborgen, solange der
  /// Angriff nicht entdeckt wird.
  final List<int> frtAttackerIds;

  const IncomingSabotageOutcome({
    required this.blockAnchor,
    required this.attackerIds,
    required this.detectedIds,
    required this.detectionPercent,
    required this.counter,
    this.frtAttackerIds = const [],
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

  /// Rivalen-IDs der **unentdeckt** gebliebenen FRT-Angriffe (Kapitel 14) –
  /// nur diese treiben die Korruption (eine entdeckte Fehl-Attribution fliegt
  /// auf und nutzt dem FRT nicht mehr).
  List<int> get undetectedFrtIds => [
    for (final id in frtAttackerIds)
      if (!detectedIds.contains(id)) id,
  ];

  /// Anzahl der unentdeckt gebliebenen FRT-Angriffe (Korruptions-Anstieg).
  int get undetectedFrtCount => undetectedFrtIds.length;
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

  /// Zwischenspeicher der **Kandidaten-Pools** (Nachrück-Reserve) je Stadtteil.
  static final Map<String, List<RivalRestaurant>> _poolCache = {};

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
  ///
  /// Die ersten `countFor(district)` Kandidaten des [candidatePool] – damit sind
  /// IDs, Persönlichkeiten und Namen zwischen Roster und Simulation stabil.
  static List<RivalRestaurant> rosterOf(String? district) {
    final key = district ?? '';
    final cached = _cache[key];
    if (cached != null) return cached;
    final roster = candidatePool(district).take(countFor(district)).toList();
    _cache[key] = roster;
    return roster;
  }

  /// Kandidaten-**Pool** des Stadtteils: der volle Roster bis
  /// `EconomyBalance.rivalCountMax` (Nachrück-Reserve der Wochen-Simulation).
  ///
  /// Rein deterministisch aus Stadtteil + Index (ID/`personalityId` per CRC32,
  /// Namen generiert und je Stadtteil zwischengespeichert). Nur die erste
  /// `countFor(district)`-Teilfolge ist der „aktive“ [rosterOf]; weitere
  /// Kandidaten rücken erst über die Roster-Dynamik nach.
  static List<RivalRestaurant> candidatePool(String? district) {
    final key = district ?? '';
    final cached = _poolCache[key];
    if (cached != null) return cached;
    final prestige = EconomyBalance.districtPrestigeFor(district);
    final zone = EconomyBalance.rivalNameZone;
    final pool = <RivalRestaurant>[
      for (var index = 0; index < EconomyBalance.rivalCountMax; index++)
        RivalRestaurant(
          id: CRC32.compute('rival:$key:$index'),
          name: RandomNames(zone).fullName(),
          district: key,
          personalityId:
              CRC32.compute('rival-personality:$key:$index') %
              EnneagramProfile.all.length,
          basePrestige: prestige,
        ),
    ];
    _poolCache[key] = pool;
    return pool;
  }

  /// Rivale mit der [id] (oder `null`).
  static RivalRestaurant? byId(Iterable<RivalRestaurant> roster, int? id) {
    if (id == null) return null;
    for (final rival in roster) {
      if (rival.id == id) return rival;
    }
    return null;
  }

  // ── Wochen-Simulation des Rivalen-Feldes (Kapitel 13, „Voll-Simulation“) ──
  //
  // Die Rivalen „rechnen selbst ab“: ihr Feld ist eine reine, deterministische
  // Funktion aus Stadtteil, Kandidaten-IDs, Spieler-PP und Wochen-Index. Es gibt
  // weder Zufall noch einen neuen Persistenzzustand (P4/V8) – derselbe Snapshot
  // liefert bei jedem Laden dasselbe Feld und dieselben Ränge.

  /// Deterministischer **Wochen-Index** aus dem Wochenanker (V8-Idempotenz).
  ///
  /// Abstand zur [EconomyBalance.rivalSimulationEpoch] in vollen Wochen; ohne
  /// Anker `0`. Derselbe Anker ⇒ derselbe Index (kein Zufall, keine Persistenz).
  /// Negative Abstände (Anker vor der Epoche) liefern `0`.
  static int weekIndexOf(DateTime? weekAnchorAt) {
    if (weekAnchorAt == null) return 0;
    final days =
        weekAnchorAt.difference(EconomyBalance.rivalSimulationEpoch).inDays;
    final weeks = days ~/ 7;
    return weeks < 0 ? 0 : weeks;
  }

  /// Simulierte PP eines Rivalen in Woche [weekIndex] (Zustand der Simulation).
  ///
  /// Basis ist das Mini-PP-Modell ([rivalPowerProjection], Rubber-Band an die
  /// Spieler-PP **ohne Zufall**); darauf liegt der langsame, deterministische,
  /// **persönlichkeitsgetriebene** Aufstieg: je Woche
  /// `rivalPpGrowthPerWeek × (rivalPpGrowthMinFactor + aggressiveness/100)`,
  /// gedeckelt über `rivalPpGrowthCapWeeks`. Dadurch wächst das Feld über die
  /// Zeit ungleichmäßig (Reihenfolge ändert sich), aber nie per Würfel (P4/V8).
  static double simulatedRivalPp(
    RivalRestaurant rival, {
    required int playerPp,
    required int weekIndex,
  }) {
    final base = rivalPowerProjection(rival, playerPp: playerPp);
    final weeks = weekIndex.clamp(0, EconomyBalance.rivalPpGrowthCapWeeks);
    final aggressiveness =
        PersonalityTraits.forProfile(rival.personalityId, rival.id)
            .aggressiveness;
    final rate = EconomyBalance.rivalPpGrowthPerWeek *
        (EconomyBalance.rivalPpGrowthMinFactor +
            aggressiveness / 100 *
                EconomyBalance.rivalPpGrowthAggressivenessSpan);
    return (base + weeks * rate).clamp(
      EconomyBalance.rivalPpMin,
      EconomyBalance.rivalPpMax,
    );
  }

  /// Rang des Spielers (1-basiert) im Kandidaten-Feld der Woche [weekIndex],
  /// rein aus der PP abgeleitet (Tie: Spieler vor dem Rivalen).
  static int playerRankIn(
    List<RivalRestaurant> pool, {
    required int playerPp,
    required int weekIndex,
  }) {
    var ahead = 0;
    for (final rival in pool) {
      if (simulatedRivalPp(rival, playerPp: playerPp, weekIndex: weekIndex) >
          playerPp) {
        ahead++;
      }
    }
    return ahead + 1;
  }

  /// Rang eines Rivalen (1-basiert) **unter den Rivalen** der Woche [weekIndex].
  ///
  /// Deterministische Gesamtordnung (PP absteigend, Tie-Break kleinere ID), damit
  /// Ränge eindeutig sind und die Ziel-Anzahl exakt eingehalten wird.
  static int _rivalRankIn(
    List<RivalRestaurant> pool,
    RivalRestaurant rival, {
    required int playerPp,
    required int weekIndex,
  }) {
    final own =
        simulatedRivalPp(rival, playerPp: playerPp, weekIndex: weekIndex);
    var ahead = 0;
    for (final other in pool) {
      if (other.id == rival.id) continue;
      final otherPp =
          simulatedRivalPp(other, playerPp: playerPp, weekIndex: weekIndex);
      if (otherPp > own || (otherPp == own && other.id < rival.id)) ahead++;
    }
    return ahead + 1;
  }

  /// Ziel-Anzahl aktiver Rivalen einer Woche: Prestige-Tier-Basis plus
  /// Gegenwind an der Spitze (Spieler führte die Vorwoche) bzw. Schrumpfen am
  /// Ende (Spieler war Vorwochen-Letzter); geklemmt auf Min/Max.
  static int roamTargetCount(
    String? district, {
    required int playerPp,
    required int weekIndex,
  }) {
    final pool = candidatePool(district);
    final base = countFor(district);
    final previousRank = playerRankIn(
      pool,
      playerPp: playerPp,
      weekIndex: weekIndex - 1,
    );
    var target = base;
    if (previousRank == 1) {
      target += EconomyBalance.rivalRosterLeadBonus;
    } else if (previousRank == pool.length + 1) {
      target -= EconomyBalance.rivalRosterTrailPenalty;
    }
    return target.clamp(
      EconomyBalance.rivalCountMin,
      EconomyBalance.rivalCountMax,
    );
  }

  /// Wochen-Regel der Roster-Dynamik (Kapitel 13): darf ein Kandidat mit diesen
  /// Merkmalen in der aktuellen Woche **aktiv** sein?
  ///
  /// Er muss **jetzt** gesund und im Zielbereich (`rankNow ≤ targetNow`) sein
  /// **und** schon in der Vorwoche gesund und im damaligen Zielbereich
  /// (`rankPrev ≤ targetPrev`). Der zweite Teil ist die **1-Tick-Verzögerung**:
  /// Ein Rivale, der erst diese Woche in den Zielbereich rückt, wird erst in der
  /// folgenden Woche aktiv – der Slot bleibt einen Tick leer (Entscheidung 3).
  static bool isRosterActive({
    required bool healthyNow,
    required bool healthyPrev,
    required int rankNow,
    required int rankPrev,
    required int targetNow,
    required int targetPrev,
  }) =>
      healthyNow &&
      rankNow <= targetNow &&
      rankPrev <= targetPrev &&
      healthyPrev;

  /// Simuliert das Rivalen-Feld einer Woche **deterministisch** (Kapitel 13,
  /// „Voll-Simulation“ Schritt 2/3).
  ///
  /// Regeln (alle rein aus Stadtteil, Kandidaten-IDs, [playerPp] und
  /// [weekIndex] – kein Zufall, kein neuer Persistenzzustand, V8/P4):
  ///
  /// 1. **Zustand:** Jeder Kandidat hat eine simulierte PP ([simulatedRivalPp],
  ///    langsamer Aufstieg); unter `rivalPpBankruptThreshold` gilt er als
  ///    **Pleite** und scheidet aus dem aktiven Feld aus.
  /// 2. **Ziel-Anzahl:** [roamTargetCount] – Prestige-Basis plus/minus Gegenwind
  ///    aus der **Vorwoche** (1-Tick-Verzögerung, Q10).
  /// 3. **Startfeld:** Aktiv sind die stärksten `target` **gesunden** Kandidaten,
  ///    jedoch nur, wenn sie **auch in der Vorwoche** gesund waren und dort
  ///    bereits im Zielbereich lagen. Dadurch bleibt ein frei werdender Slot
  ///    `rivalReplacementDelayWeeks` Tick(s) leer, bevor ein neuer Rivale
  ///    nachrückt (Entscheidung 3 → „Browsergame-Gefühl“).
  ///
  /// [previousPlayerPp] ist der Spieler-Snapshot der **Vorwoche** (Q3-Muster:
  /// „der aktuelle Wert dient als Näherung“, solange kein Vorwochen-Wert
  /// vorliegt). Ohne Angabe wird die aktuelle [playerPp] verwendet.
  static RivalFieldSimulation simulateField(
    String? district, {
    required int playerPp,
    required int weekIndex,
    int? previousPlayerPp,
  }) {
    final prevPp = previousPlayerPp ?? playerPp;
    final pool = candidatePool(district);
    // Die Roster-Entscheidung der Woche W fällt aus dem **Vorwochen**-Stand
    // (1-Tick-Verzögerung): Ziel-Anzahl aus dem Rang der Vorwoche mit deren
    // Snapshot [prevPp].
    final target = roamTargetCount(
      district,
      playerPp: prevPp,
      weekIndex: weekIndex,
    );
    final targetPrev = roamTargetCount(
      district,
      playerPp: prevPp,
      weekIndex: weekIndex - 1,
    );
    final states = <RivalWeekState>[];
    for (final rival in pool) {
      // Q7b: Die angezeigte PP des Rivalen ist um einen offenen FRT-Angriff
      // gemindert ([_ppUnderFrtPressure]); das Roster-Modell (Pleite,
      // Nachrücken, Rang für die Aktiv-Entscheidung) bleibt unverändert beim
      // reinen Wachstums-Modell, damit die 1-Tick-Verzögerung stabil bleibt.
      final pp = _ppUnderFrtPressure(
        rival,
        playerPp: playerPp,
        weekIndex: weekIndex,
      ).round();
      final ppPrev = simulatedRivalPp(
        rival,
        playerPp: prevPp,
        weekIndex: weekIndex - 1,
      );
      final rank = _rivalRankIn(
        pool,
        rival,
        playerPp: playerPp,
        weekIndex: weekIndex,
      );
      final rankPrev = _rivalRankIn(
        pool,
        rival,
        playerPp: prevPp,
        weekIndex: weekIndex - 1,
      );
      final healthy = pp >= EconomyBalance.rivalPpBankruptThreshold;
      final healthyPrev = ppPrev >= EconomyBalance.rivalPpBankruptThreshold;
      final active = isRosterActive(
        healthyNow: healthy,
        healthyPrev: healthyPrev,
        rankNow: rank,
        rankPrev: rankPrev,
        targetNow: target,
        targetPrev: targetPrev,
      );
      states.add(
        RivalWeekState(
          rival: rival,
          powerProjection: pp,
          active: active,
          insolvent: !healthy,
          joinedThisWeek: active && (rankPrev > targetPrev || !healthyPrev),
        ),
      );
    }
    return RivalFieldSimulation(
      weekIndex: weekIndex,
      playerPp: playerPp,
      playerRank: _visiblePlayerRank(states, playerPp),
      targetCount: target,
      states: states,
    );
  }

  /// Rang des Spielers (1-basiert) im **sichtbaren** Feld dieser Woche
  /// (aktive Rivalen plus ausgeschiedene) – konsistent zu [standings].
  static int _visiblePlayerRank(List<RivalWeekState> states, int playerPp) {
    var ahead = 0;
    for (final s in states) {
      if (!(s.active || s.insolvent)) continue;
      if (s.powerProjection > playerPp) ahead++;
    }
    return ahead + 1;
  }

  /// Aktive Rivalen einer Woche (Roster-Dynamik inkl. Pleite/Nachrücken).
  static List<RivalRestaurant> activeRosterOf(
    String? district, {
    required int playerPp,
    required int weekIndex,
    int? previousPlayerPp,
  }) =>
      simulateField(
        district,
        playerPp: playerPp,
        weekIndex: weekIndex,
        previousPlayerPp: previousPlayerPp,
      ).activeRivals;

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
      upgrades: restaurant.upgrades,
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
  ///
  /// [chancePercent] überschreibt die Basis-Wahrscheinlichkeit
  /// ([incomingChancePercent], § 10 `stars`): Ohne Angabe gilt
  /// `incomingSabotageChanceBasePercent` (Alt-Verhalten).
  static bool incomingAttemptOccurs(
    int rivalId,
    DateTime blockAnchor, {
    int? chancePercent,
  }) {
    final stamp = blockAnchor.toIso8601String();
    return CRC32.compute('rival-attack:$stamp:$rivalId').abs() % 100 <
        (chancePercent ?? EconomyBalance.incomingSabotageChanceBasePercent)
            .clamp(0, 100);
  }

  /// Wahrscheinlichkeit (Prozent), dass **überhaupt** ein Rivalen-Angriff beim
  /// Spieler eingeht (§ 10, `stars`): Basis-Wahrscheinlichkeit minus
  /// Sabotage-Ziel-Schutz der Auszeichnung
  /// (`sabotageTargetRelief` je Stufe), geklemmt auf `0–100`.
  static int incomingChancePercent(RestaurantData restaurant) =>
      (EconomyBalance.incomingSabotageChanceBasePercent -
              (EconomyService
                          .upgradeEffects(restaurant.upgrades)
                          .sabotageTargetRelief *
                      100)
                  .round())
          .clamp(0, 100);

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

  /// `true`, wenn der Angriff des Rivalen [rivalId] im Block [blockAnchor] in
  /// Wahrheit ein **FRT-Angriff mit Fehl-Attribution** ist (Kapitel 14, Q6).
  ///
  /// Deterministisch (`CRC32('frt-attack:<anchor>:<rivalId>')`) und unabhängig
  /// vom übrigen Zustand (V8-Idempotenz): dieselbe Verteilung bei jedem Laden.
  static bool isFrtAttack(int rivalId, DateTime blockAnchor) {
    final stamp = blockAnchor.toIso8601String();
    return CRC32.compute('frt-attack:$stamp:$rivalId').abs() % 100 <
        EconomyBalance.frtSabotageSharePercent;
  }

  /// Rivalen-IDs der Angriffe des Blocks [blockAnchor], die in Wahrheit von der
  /// FRT stammen (Roster-Reihenfolge, Kapitel 14).
  static List<int> frtAttackerIds(
    RestaurantData restaurant,
    DateTime blockAnchor,
  ) => [
    for (final rivalId in incomingAttackerIds(restaurant, blockAnchor))
      if (isFrtAttack(rivalId, blockAnchor)) rivalId,
  ];

  /// Deterministisch **behaupteter** Rivale, dem die FRT-Sabotage [rivalId] im
  /// Block [blockAnchor] angelastet wird (Q6b): ein Roster-Kollege
  /// (`CRC32('frt-attributed:<anchor>:<rivalId>') % roster.length`), damit der
  /// Verdacht zwischen den Rivalen wandert – ohne Zufall und ohne Zustand.
  static int attributedRivalId(
    RestaurantData restaurant,
    int rivalId,
    DateTime blockAnchor,
  ) {
    final roster = rosterOf(restaurant.district);
    if (roster.isEmpty) return rivalId;
    final stamp = blockAnchor.toIso8601String();
    final index =
        CRC32.compute('frt-attributed:$stamp:$rivalId').abs() % roster.length;
    return roster[index].id;
  }

  // ── FRT-Fehde & offener Angriff auf Rivalen (Kapitel 14, C2/Q7b) ───────

  /// `true`, wenn die FRT den Rivalen [rivalId] in Woche [weekIndex] **offen**
  /// angreift (Q7b).
  ///
  /// Deterministisch (`CRC32('frt-rival-attack:<week>:<id>')`) und damit
  /// idempotent über den Wochen-Index (V8) – kein neuer Persistenzzustand.
  /// Negative Wochen-Indizes (Vorwochen-Näherung vor dem Epoch) greifen nicht.
  static bool frtAttacksRival(int rivalId, int weekIndex) =>
      weekIndex >= 0 &&
      CRC32.compute('frt-rival-attack:$weekIndex:$rivalId').abs() % 100 <
          EconomyBalance.frtRivalAttackSharePercent;

  /// Power-Projection-Verlust, den ein **offener FRT-Angriff** dem Rivalen
  /// [rivalId] in Woche [weekIndex] zufügt (`0` ohne Angriff, Q7b).
  static double frtAttackPpLoss(int rivalId, int weekIndex) =>
      frtAttacksRival(rivalId, weekIndex)
          ? EconomyBalance.frtRivalAttackPpLoss
          : 0.0;

  /// Anzahl der Rivalen des Stadtteils, die die FRT in Woche [weekIndex] offen
  /// angreift (Kennzahl der Wochenabrechnung, Q7b).
  static int frtAttackedRivalCount(String? district, int weekIndex) =>
      rosterOf(district).where((r) => frtAttacksRival(r.id, weekIndex)).length;

  /// Simulierte PP **unter FRT-Druck** (Q7b): der offene FRT-Angriff senkt die
  /// PP des Rivalen, lässt ihn aber nicht unter die Pleite-Schwelle fallen –
  /// die Pleite bleibt dem Wachstums-/Roster-Modell ([simulatedRivalPp], 1-Tick-
  /// Verzögerung) vorbehalten. Dadurch bleiben die Invarianten „aktiv ⇒ gesund“
  /// und „insolvent ⇔ PP unter der Schwelle“ erhalten, während das Umfeld des
  /// Spielers sichtbar reagiert.
  static double _ppUnderFrtPressure(
    RivalRestaurant rival, {
    required int playerPp,
    required int weekIndex,
  }) {
    final base = simulatedRivalPp(
      rival,
      playerPp: playerPp,
      weekIndex: weekIndex,
    );
    final loss = frtAttackPpLoss(rival.id, weekIndex);
    if (loss <= 0) return base;
    final threshold = EconomyBalance.rivalPpBankruptThreshold;
    final floor = base >= threshold ? threshold : base;
    final attacked = base - loss;
    return attacked < floor ? floor : attacked;
  }

  /// Verschiebt [stance] um **eine Stufe** Richtung Feind (Fehde, C2):
  /// `ally → neutral → enemy`; `enemy` bleibt `enemy`.
  static RivalStance escalateStance(RivalStance stance) => switch (stance) {
        RivalStance.ally => RivalStance.neutral,
        RivalStance.neutral => RivalStance.enemy,
        RivalStance.enemy => RivalStance.enemy,
      };

  /// `true`, wenn gegen den Rivalen [rivalId] in [weekIndex] eine **FRT-Fehde**
  /// läuft (Kapitel 14, C2: Der Spieler hat die Fehl-Attribution aufgedeckt und
  /// gibt dem behaupteten Rivalen die Schuld).
  static bool feudActiveFor(
    RestaurantData restaurant,
    int rivalId,
    int weekIndex,
  ) {
    final until = restaurant.frtFeudUntilWeekById[rivalId];
    return until != null && weekIndex <= until;
  }

  /// Wendet die **aufgedeckten** FRT-Fehl-Attributionen des Blocks
  /// [blockAnchor] als **Fehde** an (Kapitel 14, C2).
  ///
  /// Betroffen ist jeweils der *behauptete* Rivale ([attributedRivalId]) des
  /// aufgedeckten Angriffs; seine Haltung bleibt
  /// `EconomyBalance.frtFeudWeeks` Wochen lang um eine Stufe feindlicher.
  /// **Nur aufgedeckte** Angriffe erzeugen eine Fehde – was unbemerkt bleibt,
  /// kann der Spieler nicht verfolgen (die Korruption steigt stattdessen,
  /// Q6/Q8). Die Fortschreibung ist idempotent je Blockanker (V8) und fasst
  /// ausschließlich [RestaurantData.frtFeudUntilWeekById] an; persistiert wird
  /// der Zustand über den Snapshot des Catch-ups.
  static void applyFrtFeud(
    RestaurantData restaurant, {
    required IncomingSabotageOutcome? incoming,
    required DateTime blockAnchor,
  }) {
    final row = incoming;
    if (row == null || row.frtAttackerIds.isEmpty) return;
    final detected = row.detectedIds.toSet();
    final week = weekIndexOf(blockAnchor);
    final until = week + EconomyBalance.frtFeudWeeks;
    Map<int, int>? updated;
    for (final rivalId in row.frtAttackerIds) {
      if (!detected.contains(rivalId)) continue;
      final blamed = attributedRivalId(restaurant, rivalId, blockAnchor);
      final current = restaurant.frtFeudUntilWeekById[blamed];
      if (current == null || current < until) {
        // Bewusst eine **frische** Map statt In-Place-Mutation: So bleibt der
        // Aufruf auch dann sicher, wenn der Spielstand eine unveränderliche Map
        // mitbringt (z. B. `const {}` aus Tests oder einer kompakten
        // Deserialisierung).
        updated ??= Map.of(restaurant.frtFeudUntilWeekById);
        updated[blamed] = until;
      }
    }
    if (updated != null) restaurant.frtFeudUntilWeekById = updated;
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
  /// (`securityChiefDetectionBonusPercentPerCompetence`) plus dem
  /// Erweiterungs-Zuschlag der **Sicherheitstechnik** (`security`, § 10;
  /// `detectionBonus` je Stufe), auf `100` gedeckelt.
  static int incomingDetectionPercent(RestaurantData restaurant) =>
      ((averageShadiness(restaurant) *
                      EconomyBalance.incomingDetectionShadinessToPercent /
                      100)
                  .round() +
              StaffRoleService.securityChiefDetectionBonusPercent(
                restaurant.staffEntries,
              ) +
              (EconomyService.upgradeEffects(restaurant.upgrades).detectionBonus *
                      100)
                  .round())
          .clamp(0, 100);

  /// Rivalen-IDs aller Angreifer des Blocks [blockAnchor] (Roster-Reihenfolge).
  ///
  /// Die Angriffs-Wahrscheinlichkeit kommt aus [incomingChancePercent] – so
  /// wirkt der Sabotage-Ziel-Schutz der Auszeichnung (`stars`, § 10) auf
  /// **alle** Konsumenten (Auflösung, Entdeckung, FRT-Attribution, Rangliste)
  /// gleichzeitig.
  static List<int> incomingAttackerIds(
    RestaurantData restaurant,
    DateTime blockAnchor,
  ) {
    final chance = incomingChancePercent(restaurant);
    return [
      for (final rival in rosterOf(restaurant.district))
        if (incomingAttemptOccurs(rival.id, blockAnchor, chancePercent: chance))
          rival.id,
    ];
  }

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
      upgrades: restaurant.upgrades,
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
    // Kapitel 14 (Q6): Ein Teil der Angriffe stammt in Wahrheit von der FRT
    // (Fehl-Attribution) – deterministisch und unabhängig von der Entdeckung.
    final frt = [
      for (final rivalId in attackers)
        if (isFrtAttack(rivalId, blockAnchor)) rivalId,
    ];
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
      frtAttackerIds: frt,
    );
  }

  // ── Mini-PP-Modell, Rangliste, Stance & Gefechtsteilnahme (Kap. 12/13) ──

  /// Signierter, deterministischer Hash-Wert in `[−amplitude, amplitude]`.
  static double _signedHash(String key, int amplitude) {
    if (amplitude <= 0) return 0.0;
    final span = 2 * amplitude + 1;
    return (CRC32.compute(key).abs() % span) - amplitude.toDouble();
  }

  /// Simulierte Power Projection eines Rivalen (Domäne 0–100, deterministisch).
  ///
  /// Grund-PP aus dem Stadtteil-Prestige, deterministische Streuung je Rivale und
  /// ein Rubber-Band zur Spieler-PP (Q6: skalierendes Feld **ohne Zufall**,
  /// idempotent über [RestaurantData] + Rivalen-ID, V8).
  static double rivalPowerProjection(
    RivalRestaurant rival, {
    required int playerPp,
  }) {
    final base =
        EconomyBalance.rivalPpPrestigeBase +
        (rival.basePrestige - EconomyBalance.rivalPpPrestigeOrigin) *
            EconomyBalance.rivalPpPrestigeScale;
    final jitter = _signedHash(
      'rival-pp:${rival.id}',
      EconomyBalance.rivalPpJitterAmplitude,
    );
    final rubber = _signedHash(
      'rival-rubber:${rival.id}',
      EconomyBalance.rivalPpRubberBandAmplitude,
    );
    final w = EconomyBalance.rivalPpRubberBandWeight;
    final value = (base + jitter) * (1 - w) + (playerPp + rubber) * w;
    return value.clamp(EconomyBalance.rivalPpMin, EconomyBalance.rivalPpMax);
  }

  /// Relative Stance eines Rivalen zur Spieler-PP (Q9).
  ///
  /// Relativer Abstand `|ΔPP| / max(PP)`; die Schwellen sind die Zentren
  /// „Verbündet“ (≤ 20 %), „Neutral“ (≈ 50 %) und „Feind“ (≥ 80 %), die
  /// dazwischen per Mittelpunkt getrennt werden.
  static RivalStance stanceForRival({
    required int rivalPp,
    required int playerPp,
  }) {
    final hi = rivalPp > playerPp ? rivalPp : playerPp;
    final gap = hi == 0 ? 0.0 : (rivalPp - playerPp).abs() / hi;
    final allyBoundary =
        (EconomyBalance.stanceAllyGap + EconomyBalance.stanceNeutralGap) / 2;
    final enemyBoundary =
        (EconomyBalance.stanceNeutralGap + EconomyBalance.stanceEnemyGap) / 2;
    if (gap < allyBoundary) return RivalStance.ally;
    if (gap < enemyBoundary) return RivalStance.neutral;
    return RivalStance.enemy;
  }

  /// Rangliste (Spieler **und** Rivalen) des Stadtteils, absteigend nach PP.
  ///
  /// Deterministisch: gleiche [playerPp] und [RestaurantData] ⇒ gleiche Liste
  /// (Tie-Break: Spieler zuerst, dann kleinere ID).
  ///
  /// Ist [weekIndex] gesetzt, fließt die **Wochen-Simulation** ([simulateField])
  /// ein: Es erscheinen nur die **aktiven** Rivalen plus die als **Pleite**
  /// ausgeschiedenen (mit Pleite-Kennzeichnung); `rivalAveragePp` mittelt nur
  /// über die aktiven – so wirkt die Roster-Dynamik direkt auf den Konkurrenz-
  /// druck (Q10). Ohne [weekIndex] bleibt das Verhalten statisch (Alt-Verhalten).
  static DistrictStandings standings(
    RestaurantData restaurant, {
    required int playerPp,
    int? weekIndex,
    int? previousPlayerPp,
  }) {
    final RivalFieldSimulation? sim = weekIndex == null
        ? null
        : simulateField(
            restaurant.district,
            playerPp: playerPp,
            weekIndex: weekIndex,
            previousPlayerPp: previousPlayerPp,
          );
    final roster = sim == null
        ? rosterOf(restaurant.district)
        : [
            for (final s in sim.states)
              if (s.active || s.insolvent) s.rival,
          ];
    final activeIds = sim == null
        ? <int>{}
        : {for (final s in sim.activeStates) s.rival.id};
    double ppOf(RivalRestaurant r) => sim == null
        ? rivalPowerProjection(r, playerPp: playerPp)
        : _ppUnderFrtPressure(
            r,
            playerPp: playerPp,
            weekIndex: weekIndex!,
          );
    final pps = <int, double>{for (final r in roster) r.id: ppOf(r)};
    // C2: Die Fehde-Länge ist in Wochen-Indizes gespeichert; ohne expliziten
    // [weekIndex] zählt der Index des aktuellen Wochenankers.
    final feudWeek = weekIndex ?? weekIndexOf(restaurant.weekAnchorAt);
    final rows = <RivalStanding>[
      RivalStanding(
        id: kPlayerStandingId,
        name: restaurant.name,
        powerProjection: playerPp.clamp(
          0,
          EconomyBalance.powerProjectionDomainMax,
        ),
        isPlayer: true,
        stance: null,
        insolvent: false,
        rank: 0,
      ),
    ];
    for (final r in roster) {
      final rawPp = pps[r.id]!;
      final rivalPp = rawPp.round();
      final stance = stanceForRival(rivalPp: rivalPp, playerPp: playerPp);
      rows.add(
        RivalStanding(
          id: r.id,
          name: r.name,
          powerProjection: rivalPp.clamp(
            0,
            EconomyBalance.powerProjectionDomainMax,
          ),
          isPlayer: false,
          // C2: Eine laufende FRT-Fehde stimmt den behaupteten Rivalen um eine
          // Stufe feindlicher – sichtbar in der Rangliste **und** im Gefecht
          // (`battleParticipants`).
          stance: feudActiveFor(restaurant, r.id, feudWeek)
              ? escalateStance(stance)
              : stance,
          insolvent: rawPp < EconomyBalance.rivalPpBankruptThreshold,
          rank: 0,
        ),
      );
    }
    rows.sort((a, b) {
      final byPp = b.powerProjection.compareTo(a.powerProjection);
      if (byPp != 0) return byPp;
      if (a.isPlayer != b.isPlayer) return a.isPlayer ? -1 : 1;
      return a.id.compareTo(b.id);
    });
    for (var i = 0; i < rows.length; i++) {
      rows[i].rank = i + 1;
    }
    final List<double> counted = sim == null
        ? [for (final v in pps.values) v]
        : [
            for (final r in roster)
              if (activeIds.contains(r.id) &&
                  pps[r.id]! >= EconomyBalance.rivalPpBankruptThreshold)
                pps[r.id]!.round().toDouble(),
          ];
    final double average =
        counted.isEmpty ? 0.0 : counted.reduce((a, b) => a + b) / counted.length;
    final playerRank = rows.firstWhere((e) => e.isPlayer).rank;
    return DistrictStandings(
      entries: rows,
      playerRank: playerRank,
      rivalAveragePp: average,
    );
  }

  /// Anzahl der Gefechtsteilnehmer (1–4 bzw. gedeckelt durch die Roster-Größe).
  static int battleParticipantCount(RestaurantData restaurant, {int? seed}) {
    final roster = rosterOf(restaurant.district);
    if (roster.isEmpty) return 0;
    final base = seed ?? restaurant.id;
    final span =
        EconomyBalance.rivalBattleMaxParticipants -
        EconomyBalance.rivalBattleMinParticipants +
        1;
    final raw =
        (CRC32.compute('battle-participants:$base').abs() % span) +
        EconomyBalance.rivalBattleMinParticipants;
    return raw
        .clamp(
          EconomyBalance.rivalBattleMinParticipants,
          EconomyBalance.rivalBattleMaxParticipants,
        )
        .clamp(0, roster.length);
  }

  /// Deterministische Gefechtsteilnehmer (Rivalen-IDs) des Stadtteils (Q8).
  ///
  /// Die stärksten Rivalen (PP absteigend, Tie-Break kleinere ID) nehmen teil.
  static List<int> battleParticipantIds(
    RestaurantData restaurant, {
    required int playerPp,
    int? seed,
  }) {
    final roster = rosterOf(restaurant.district);
    if (roster.isEmpty) return const [];
    final desired = battleParticipantCount(restaurant, seed: seed);
    final pps = <int, double>{
      for (final r in roster) r.id: rivalPowerProjection(r, playerPp: playerPp),
    };
    final ordered = [...roster]
      ..sort((a, b) {
        final byPp = pps[b.id]!.compareTo(pps[a.id]!);
        if (byPp != 0) return byPp;
        return a.id.compareTo(b.id);
      });
    return [for (final r in ordered.take(desired)) r.id];
  }

  /// Verteilt [participantCount] Teilnehmer auf [availableSpawns]
  /// `spawn_player*`-Punkte (Frage 8 ⇒ „Verteilung“).
  ///
  /// Reicht die Kartenzahl nicht, werden die Teilnehmer **round-robin** auf die
  /// vorhandenen Punkte verteilt (mehrere Teilnehmer dürfen sich einen Punkt
  /// teilen); das Ergebnis ist der Punkt-Index je Teilnehmer.
  static List<int> distributeBattleSpawns({
    required int participantCount,
    required int availableSpawns,
  }) {
    if (availableSpawns <= 0 || participantCount <= 0) return const [];
    return [for (var i = 0; i < participantCount; i++) i % availableSpawns];
  }

  /// Truppenstärke eines teilnehmenden Rivalen (Fairness, Q8).
  ///
  /// Rein aus der simulierten Rivalen-PP abgeleitet: 1 Einheit plus je
  /// [EconomyBalance.rivalBattleTeamSizePpStep] PP eine weitere, gedeckelt auf
  /// [EconomyBalance.rivalBattleMaxTeamSize] – keine versteckten Armeen.
  static int battleTeamSizeForPp(num rivalPp) {
    final extra =
        (rivalPp / EconomyBalance.rivalBattleTeamSizePpStep).floor();
    return (1 + extra).clamp(1, EconomyBalance.rivalBattleMaxTeamSize);
  }

  /// Deterministische Rivalen-Teilnehmer eines Gefechts (Q8/Q9) inklusive
  /// Stance, Truppenstärke und Ziel-Spawnpunkt.
  ///
  /// Baut auf [battleParticipantIds] (stärkste Rivalen zuerst) und
  /// [distributeBattleSpawns] auf; [availableSpawns] ist die Zahl der
  /// `spawn_player*`-Punkte der gewählten Karte.
  static List<BattleRivalParticipant> battleParticipants(
    RestaurantData restaurant, {
    required int playerPp,
    required int availableSpawns,
    int? seed,
  }) {
    final ids = battleParticipantIds(restaurant, playerPp: playerPp, seed: seed);
    if (ids.isEmpty) return const [];
    final roster = rosterOf(restaurant.district);
    final spawns = distributeBattleSpawns(
      participantCount: ids.length,
      availableSpawns: availableSpawns,
    );
    // C2: Eine laufende FRT-Fehde stimmt den behaupteten Rivalen auch im
    // Gefecht eine Stufe feindlicher (konsistent zur Rangliste).
    final feudWeek = weekIndexOf(restaurant.weekAnchorAt);
    return [
      for (var i = 0; i < ids.length; i++)
        () {
          final rival = byId(roster, ids[i])!;
          final pp = rivalPowerProjection(rival, playerPp: playerPp);
          final rounded = pp.round();
          final stance = stanceForRival(rivalPp: rounded, playerPp: playerPp);
          return BattleRivalParticipant(
            rivalId: rival.id,
            name: rival.name,
            stance: feudActiveFor(restaurant, rival.id, feudWeek)
                ? escalateStance(stance)
                : stance,
            teamSize: battleTeamSizeForPp(pp),
            spawnIndex: spawns[i],
          );
        }(),
    ];
  }
}

/// Ein deterministisch bestimmter Rivalen-Teilnehmer eines Gefechts
/// (Kapitel 13, Q8/Q9): wer mit welcher Haltung, Truppenstärke und auf welchem
/// `spawn_player*`-Punkt der Karte beitritt.
class BattleRivalParticipant {
  /// Rivalen-ID.
  final int rivalId;

  /// Anzeigename des Rivalen.
  final String name;

  /// Haltung zum Spieler ([RivalStance]).
  final RivalStance stance;

  /// Truppenstärke (Einheiten), die der Rivale ins Gefecht bringt.
  final int teamSize;

  /// Index des `spawn_player*`-Punktes (0-basiert), auf dem die Truppe startet.
  final int spawnIndex;

  const BattleRivalParticipant({
    required this.rivalId,
    required this.name,
    required this.stance,
    required this.teamSize,
    required this.spawnIndex,
  });

  @override
  String toString() =>
      'BattleRivalParticipant(#$rivalId, $name, $stance, '
      'size=$teamSize, spawn=$spawnIndex)';
}

/// Sentinel-ID des Spielers in der Stadtteil-Rangliste.
const int kPlayerStandingId = -1;

/// Zustand eines Rivalen-Kandidaten in einer simulierten Woche
/// (Kapitel 13, „Voll-Simulation“).
///
/// Rein abgeleitet (`RivalService.simulateField`) – keine Persistenz (V8).
class RivalWeekState {
  /// Der Kandidat.
  final RivalRestaurant rival;

  /// Simulierte PP dieser Woche (0–100).
  final int powerProjection;

  /// `true`, wenn der Kandidat in dieser Woche zum aktiven Feld gehört.
  final bool active;

  /// `true`, wenn die PP unter `rivalPpBankruptThreshold` liegt (Pleite).
  final bool insolvent;

  /// `true`, wenn der Kandidat in dieser Woche **nachrückt** (durch einen frei
  /// gewordenen Slot nach der `rivalReplacementDelayWeeks`-Verzögerung).
  final bool joinedThisWeek;

  const RivalWeekState({
    required this.rival,
    required this.powerProjection,
    required this.active,
    required this.insolvent,
    required this.joinedThisWeek,
  });

  @override
  String toString() =>
      'RivalWeekState(#${rival.id}, pp=$powerProjection, active=$active, '
      'insolvent=$insolvent, joined=$joinedThisWeek)';
}

/// Ergebnis der deterministischen **Wochen-Simulation** des Rivalen-Feldes
/// (Kapitel 13, „Voll-Simulation“): Zustand aller Kandidaten, Ziel-Anzahl,
/// Spieler-Rang und der daraus abgeleitete aktive Roster.
class RivalFieldSimulation {
  /// Deterministischer Wochen-Index (siehe `RivalService.weekIndexOf`).
  final int weekIndex;

  /// Spieler-PP, mit der das Feld simuliert wurde.
  final int playerPp;

  /// Rang des Spielers im **sichtbaren** Feld dieser Woche (aktive Rivalen plus
  /// ausgeschiedene, 1-basiert) – konsistent zur Rangliste ([standings]).
  final int playerRank;

  /// Ziel-Anzahl aktiver Rivalen dieser Woche.
  final int targetCount;

  /// Zustand **aller** Kandidaten in Pool-Reihenfolge.
  final List<RivalWeekState> states;

  const RivalFieldSimulation({
    required this.weekIndex,
    required this.playerPp,
    required this.playerRank,
    required this.targetCount,
    required this.states,
  });

  /// Aktive Kandidaten dieser Woche.
  List<RivalWeekState> get activeStates =>
      [for (final s in states) if (s.active) s];

  /// Aktive Rivalen dieser Woche (Pool-Reihenfolge).
  List<RivalRestaurant> get activeRivals =>
      [for (final s in activeStates) s.rival];

  /// In dieser Woche nachgerückte Rivalen (frei gewordener Slot).
  List<RivalRestaurant> get joinedRivals =>
      [for (final s in states) if (s.joinedThisWeek) s.rival];

  /// Als **Pleite** ausgeschiedene Kandidaten dieser Woche.
  List<RivalRestaurant> get insolventRivals =>
      [for (final s in states) if (s.insolvent) s.rival];

  /// Anzahl aktiver Rivalen.
  int get activeCount => activeStates.length;

  /// Durchschnittliche PP der **aktiven** Rivalen (für den Konkurrenzdruck, Q10).
  double get activeAveragePp => activeStates.isEmpty
      ? 0.0
      : activeStates.fold<int>(0, (sum, s) => sum + s.powerProjection) /
          activeStates.length;

  @override
  String toString() =>
      'RivalFieldSimulation(week=$weekIndex, playerPp=$playerPp, '
      'rank=$playerRank, target=$targetCount, active=$activeCount)';
}


/// Haltung eines Rivalen zum Spieler (Kapitel 13, Q9).
enum RivalStance {
  /// PP nahezu gleich (≤ 20 % Abstand) – Chance auf Verbündete hoch.
  ally,

  /// Mittlerer Abstand (≈ 50 %) – Chance auf Neutralität hoch.
  neutral,

  /// Großer Abstand (≥ 80 %) – Chance auf Feindschaft hoch.
  enemy,
}

/// Ein Eintrag der Stadtteil-Rangliste (Spieler **oder** Rivale).
///
/// Rein abgeleiteter Zustand (Q3: keine Persistenz) – wird je Catch-up aus dem
/// Restaurant-Snapshot und dem deterministischen Rivalen-Mini-Modell erzeugt.
class RivalStanding {
  /// Rivalen-ID oder [kPlayerStandingId] für den Spieler.
  final int id;

  /// Anzeigename.
  final String name;

  /// Power Projection (0–100).
  final int powerProjection;

  /// `true` für den Eintrag des Spielers.
  final bool isPlayer;

  /// Haltung zum Spieler (nur für Rivalen gesetzt, sonst `null`).
  final RivalStance? stance;

  /// `true`, wenn die Rivalen-PP unter [EconomyBalance.rivalPpBankruptThreshold]
  /// liegt (Pleite-Kennzeichnung in der Rangliste).
  final bool insolvent;

  /// Platzierung (1-basiert), absteigend nach [powerProjection].
  int rank;

  RivalStanding({
    required this.id,
    required this.name,
    required this.powerProjection,
    required this.isPlayer,
    required this.stance,
    required this.insolvent,
    required this.rank,
  });

  @override
  String toString() =>
      'RivalStanding(#$rank, $name, pp=$powerProjection, '
      'player=$isPlayer, stance=$stance)';
}

/// Ergebnis der Stadtteil-Rangliste eines Catch-ups (Spieler + Rivalen).
class DistrictStandings {
  /// Alle Einträge, absteigend nach PP (Index 0 = Platz 1).
  final List<RivalStanding> entries;

  /// Platzierung des Spielers (1-basiert).
  final int playerRank;

  /// Durchschnittliche PP der Rivalen (für den Konkurrenzdruck, Q10).
  final double rivalAveragePp;

  const DistrictStandings({
    required this.entries,
    required this.playerRank,
    required this.rivalAveragePp,
  });

  /// Anzahl aller Beteiligten (Spieler + Rivalen).
  int get total => entries.length;

  /// Der Eintrag des Spielers.
  RivalStanding get player => entries.firstWhere((e) => e.isPlayer);
}
