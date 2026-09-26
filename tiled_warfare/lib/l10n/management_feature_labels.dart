import 'package:tiled_warfare/l10n/app_localizations.dart';
import 'package:tiled_warfare/models/management_feature.dart';

/// Übersetzt ein aktives Feature in den lokalisierten Namen (Option C, `11a`).
String managementFeatureLabel(
  AppLocalizations l10n,
  ManagementFeature feature,
) => switch (feature) {
  ManagementFeature.prCampaign => l10n.managementFeaturePrCampaign,
  ManagementFeature.sabotage => l10n.managementFeatureSabotage,
  ManagementFeature.legalTrick => l10n.managementFeatureLegalTrick,
  ManagementFeature.creativeAccounting =>
    l10n.managementFeatureCreativeAccounting,
  ManagementFeature.rushHour => l10n.managementFeatureRushHour,
  ManagementFeature.organisationIsEverything =>
    l10n.managementFeatureOrganisationIsEverything,
  ManagementFeature.storageTetris => l10n.managementFeatureStorageTetris,
  ManagementFeature.unionWorkers => l10n.managementFeatureUnionWorkers,
  ManagementFeature.counterSabotage => l10n.managementFeatureCounterSabotage,
};

/// Kurzbeschreibung der Wirkung eines Features (Option C, `11a`).
String managementFeatureEffectLabel(
  AppLocalizations l10n,
  ManagementFeature feature,
) => switch (feature) {
  ManagementFeature.prCampaign => l10n.managementFeaturePrCampaignEffect,
  ManagementFeature.sabotage => l10n.managementFeatureSabotageEffect,
  ManagementFeature.legalTrick => l10n.managementFeatureLegalTrickEffect,
  ManagementFeature.creativeAccounting =>
    l10n.managementFeatureCreativeAccountingEffect,
  ManagementFeature.rushHour => l10n.managementFeatureRushHourEffect,
  ManagementFeature.organisationIsEverything =>
    l10n.managementFeatureOrganisationIsEverythingEffect,
  ManagementFeature.storageTetris => l10n.managementFeatureStorageTetrisEffect,
  ManagementFeature.unionWorkers => l10n.managementFeatureUnionWorkersEffect,
  ManagementFeature.counterSabotage =>
    l10n.managementFeatureCounterSabotageEffect,
};

/// Übersetzt einen Feature-Schlüssel (`ManagementFeature.name`) in den
/// Anzeigenamen; unbekannte Schlüssel liefern `null`.
String? managementFeatureLabelFor(AppLocalizations l10n, String featureKey) {
  for (final feature in ManagementFeature.values) {
    if (feature.name == featureKey) {
      return managementFeatureLabel(l10n, feature);
    }
  }
  return null;
}
