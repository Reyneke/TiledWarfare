import 'package:random_name_generator/random_name_generator.dart';
import 'package:tiled_warfare/models/management_feature.dart';
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
/// Nicht Teil dieses Minimal-Moduls: Power Projection/Rangliste, Gefechts-
/// teilnahme, Rivalen-Simulation und Rivalen-Sabotage gegen den Spieler
/// (Kapitel 13 → „Handlungen (Prototyp)“ Schritte 2–3).
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
        EconomyBalance.rivalCountMin, EconomyBalance.rivalCountMax);
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
  ) =>
      sabotageBonusActive(restaurant, now)
          ? EconomyBalance.sabotageIncomeBonusPercent
          : 0;

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

    final resolvedAt =
        ManagementFeatureService.activeEndOf(entry) ?? now;
    entry.featureResolvedAt = resolvedAt;
    if (ManagementFeatureService.sabotageSucceeds(entry, rivalId)) {
      restaurant.sabotageTargetId = rivalId;
      restaurant.sabotageAppliedUntil =
          resolvedAt.add(EconomyBalance.sabotageEffectDuration);
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
}
