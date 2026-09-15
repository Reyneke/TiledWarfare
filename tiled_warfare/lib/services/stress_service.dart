import 'dart:math';

import 'package:tiled_warfare/models/personality.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/objects/player_objects/object_apprentice.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/economy_service.dart';

/// Ergebnis eines Ressourcen-Sinks (V9 § 6).
class ResourceSink {
  /// Neuer Wert (Domäne 0–100).
  final int value;

  /// `true`, wenn der Wert (weiterhin) auf 0 steht.
  final bool atZero;

  const ResourceSink(this.value, this.atZero);
}

/// Geplanter Stress-/Ruhe-Persönlichkeitswechsel (V9 § 6).
class PersonalityOverride {
  /// Index des temporär wirksamen Profils in `EnneagramProfile.all`.
  final int profileId;

  /// Dauer des Wechsels (ab jetzt).
  final Duration duration;

  /// Auslöser: `stress` oder `ruhe`.
  final String cause;

  const PersonalityOverride({
    required this.profileId,
    required this.duration,
    required this.cause,
  });
}

/// Stress & Ruhe (V9 § 6): W100-Proben, Dauerstaffel und Erschöpfungs-Malus.
///
/// Alle Funktionen sind **rein** und erhalten den Zufall als Parameter
/// (injizierbarer `Random`, V7/L7) – dadurch sind Proben deterministisch
/// testbar. Grundlage: `doc/todo/feat_better_restaurant_management/9_Personal.md`.
class StressService {
  /// Senkt einen Ressourcenwert um [amount] und meldet, ob er auf 0 steht.
  static ResourceSink sink(int current, int amount) {
    final value = (current - amount)
        .clamp(EconomyBalance.resourceMin, EconomyBalance.resourceMax);
    return ResourceSink(value, value <= EconomyBalance.resourceMin);
  }

  /// Pflegt den Null-Anker: gesetzt beim ersten Erreichen von 0, gelöscht,
  /// sobald die Ressource wieder über 0 steht (idempotent, V3-Muster).
  static DateTime? updateZeroAnchor(
    DateTime? anchor, {
    required bool atZero,
    required DateTime now,
  }) =>
      atZero ? (anchor ?? now) : null;

  /// Kumulativer Erschöpfungs-Malus in Prozentpunkten (V9 § 6).
  ///
  /// Jeder Tag mit **einer** Ressource auf 0: +`resourceZeroMalusPerDay`.
  /// Tage, an denen **beide** auf 0 stehen: +`resourceZeroMalusPerDayBoth`.
  /// Kein Cap – der Wochen-Refill setzt zurück.
  static int exhaustionMalusPercent({
    DateTime? vitalityZeroSinceAt,
    DateTime? moraleZeroSinceAt,
    required DateTime now,
  }) {
    final vDays = _zeroDays(vitalityZeroSinceAt, now);
    final mDays = _zeroDays(moraleZeroSinceAt, now);
    final bothDays = min(vDays, mDays);
    final singleDays = max(vDays, mDays) - bothDays;
    return singleDays * EconomyBalance.resourceZeroMalusPerDay +
        bothDays * EconomyBalance.resourceZeroMalusPerDayBoth;
  }

  /// Erschöpfungs-Malus aus den Ankern einer [StaffData] (Snapshot-Pfad).
  static int malusPercentForStaffData(StaffData staff, DateTime now) =>
      exhaustionMalusPercent(
        vitalityZeroSinceAt: staff.vitalityZeroSinceAt,
        moraleZeroSinceAt: staff.moraleZeroSinceAt,
        now: now,
      );

  /// Erschöpfungs-Malus aus den Ankern eines Charakters (Gefechtspfad).
  static int malusPercentForCharacter(
          ObjectApprentice character, DateTime now) =>
      exhaustionMalusPercent(
        vitalityZeroSinceAt: character.vitalityZeroSinceAt,
        moraleZeroSinceAt: character.moraleZeroSinceAt,
        now: now,
      );

  /// W100-Zielwert nach Malus (Domäne bleibt 1–100).
  static int targetAfterMalus(int target, int malusPercent) =>
      EconomyService.clampTargetToD100(target - malusPercent);

  /// Führt die Proben eines Verlust-Ereignisses aus (je Ressource ein Wurf).
  ///
  /// Rückgabe: der geplante Persönlichkeitswechsel oder `null` (alles gut).
  /// Stress hat Vorrang vor Ruhe.
  static PersonalityOverride? probe({
    required int vitalityCurrent,
    required int moraleCurrent,
    required int currentProfileId,
    required Random random,
    int malusPercent = 0,
  }) {
    final v = _probeOne(vitalityCurrent, currentProfileId, random, malusPercent);
    final m = _probeOne(moraleCurrent, currentProfileId, random, malusPercent);
    if (v != null && v.cause == 'stress') return v;
    if (m != null && m.cause == 'stress') return m;
    return v ?? m;
  }

  /// Dauer der Staffel aus dem Über-/Unterschreitungsbetrag (V9 § 6).
  static Duration durationForMargin(int margin, Random random) {
    if (margin <= 0) return Duration.zero;
    if (margin <= EconomyBalance.stressMarginSingleTick) {
      return EconomyBalance.einzelTickUnit *
          (1 + random.nextInt(EconomyBalance.stressDiceW6));
    }
    if (margin <= EconomyBalance.stressMarginDays) {
      return EconomyBalance.stressDayUnit *
          (1 + random.nextInt(EconomyBalance.stressDiceW4));
    }
    if (margin <= EconomyBalance.stressMarginWeeks) {
      return EconomyBalance.stressWeekUnit *
          (1 + random.nextInt(EconomyBalance.stressDiceW4));
    }
    return EconomyBalance.stressMonthUnit *
        (1 + random.nextInt(EconomyBalance.stressDiceW4));
  }

  /// Wählt ein temporär wirksames Profil (nie identisch mit [currentProfileId]).
  static int overrideProfileId(int currentProfileId, Random random) {
    final total = EnneagramProfile.all.length;
    final pick = random.nextInt(total);
    return pick == currentProfileId ? (pick + 1) % total : pick;
  }

  static int _zeroDays(DateTime? since, DateTime now) =>
      since == null ? 0 : max(0, now.difference(since).inDays);

  static PersonalityOverride? _probeOne(
    int value,
    int currentProfileId,
    Random random,
    int malusPercent,
  ) {
    final target = targetAfterMalus(value, malusPercent);
    final roll = EconomyService.rollD100(random);
    if (roll > target) {
      final margin = roll - target;
      return PersonalityOverride(
        profileId: overrideProfileId(currentProfileId, random),
        duration: durationForMargin(margin, random),
        cause: 'stress',
      );
    }
    if (roll <= target - EconomyBalance.ruheMargin) {
      final margin = target - roll;
      return PersonalityOverride(
        profileId: overrideProfileId(currentProfileId, random),
        duration: durationForMargin(margin, random),
        cause: 'ruhe',
      );
    }
    return null;
  }
}