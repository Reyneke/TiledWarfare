import 'package:tiled_warfare/l10n/app_localizations.dart';
import 'package:tiled_warfare/models/management_feature.dart';
import 'package:tiled_warfare/models/staff_entry.dart';
import 'package:tiled_warfare/services/management_feature_service.dart';

/// Kompakte Zeitangabe (Tag.Monat Stunde:Minute) für Feature-Countdowns.
String formatFeatureUntil(DateTime? until) {
  if (until == null) return '—';
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(until.day)}.${two(until.month)} '
      '${two(until.hour)}:${two(until.minute)}';
}

/// Statuszeile des von [entry] getragenen Features zum Zeitpunkt [now] – oder
/// `null`, wenn kein Feature läuft (`11a` P4).
///
/// Die Auswertung ist **anker-basiert** (`featureActivatedAt`) und damit
/// idempotent; sie wird vom Personal-Screen (`ScreenHireAndFire`) **und** vom
/// Restaurant-Screen (Feature-Countdown außerhalb der Personal-Karte) genutzt,
/// damit beide dieselbe Sprache sprechen. Sabotage und Gegenschlag haben ein
/// eigenes Vokabular (Auflösung im Wochentick bzw. Scharfschaltung) und nutzen
/// dafür [sabotageAppliedUntil] aus dem Restaurant-Zustand.
String? managementFeatureStatusLine(
  AppLocalizations l10n,
  StaffEntryData entry,
  DateTime now, {
  DateTime? sabotageAppliedUntil,
}) {
  final feature = managementFeatureFromName(entry.activeFeature);
  final activatedAt = entry.featureActivatedAt;
  if (feature == null || activatedAt == null) return null;

  final activeEnd = ManagementFeatureService.activeEndOf(entry);
  final aftermathEnd = ManagementFeatureService.aftermathEndOf(entry);
  final isActive =
      !now.isBefore(activatedAt) &&
      (activeEnd == null || !now.isAfter(activeEnd));
  final isInAftermath =
      activeEnd != null &&
      now.isAfter(activeEnd) &&
      (aftermathEnd == null || !now.isAfter(aftermathEnd));
  final effectUntil = sabotageAppliedUntil;
  final effectRunning =
      entry.featureResolvedAt != null &&
      effectUntil != null &&
      now.isBefore(effectUntil);

  switch (feature) {
    case ManagementFeature.sabotage:
      if (isActive) {
        return l10n.managementSabotagePending(formatFeatureUntil(activeEnd));
      }
      if (effectRunning) {
        return l10n.managementSabotageEffect(formatFeatureUntil(effectUntil));
      }
      return null;
    case ManagementFeature.counterSabotage:
      if (isActive && entry.featureResolvedAt == null) {
        return l10n.managementCounterSabotagePending(
          formatFeatureUntil(activeEnd),
        );
      }
      if (effectRunning) {
        return l10n.managementSabotageEffect(formatFeatureUntil(effectUntil));
      }
      return null;
    case ManagementFeature.prCampaign:
    case ManagementFeature.legalTrick:
    case ManagementFeature.creativeAccounting:
    case ManagementFeature.rushHour:
    case ManagementFeature.organisationIsEverything:
    case ManagementFeature.storageTetris:
    case ManagementFeature.unionWorkers:
      if (isActive) {
        return l10n.managementFeatureActive(formatFeatureUntil(activeEnd));
      }
      if (isInAftermath) {
        return l10n.managementFeatureAftermath(
          formatFeatureUntil(aftermathEnd),
        );
      }
      return null;
  }
}
