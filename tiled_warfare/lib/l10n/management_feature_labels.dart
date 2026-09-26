import 'package:tiled_warfare/l10n/app_localizations.dart';
import 'package:tiled_warfare/models/management_feature.dart';

/// Übersetzt ein aktives Feature in den lokalisierten Namen (Option C, `11a`).
String managementFeatureLabel(AppLocalizations l10n, ManagementFeature feature) =>
    switch (feature) {
      ManagementFeature.prCampaign => l10n.managementFeaturePrCampaign,
      ManagementFeature.sabotage => l10n.managementFeatureSabotage,
      ManagementFeature.legalTrick => l10n.managementFeatureLegalTrick,
      ManagementFeature.creativeAccounting =>
        l10n.managementFeatureCreativeAccounting,
    };

/// Kurzbeschreibung der Wirkung eines Features (Option C, `11a`).
String managementFeatureEffectLabel(
        AppLocalizations l10n, ManagementFeature feature) =>
    switch (feature) {
      ManagementFeature.prCampaign => l10n.managementFeaturePrCampaignEffect,
      ManagementFeature.sabotage => l10n.managementFeatureSabotageEffect,
      ManagementFeature.legalTrick => l10n.managementFeatureLegalTrickEffect,
      ManagementFeature.creativeAccounting =>
        l10n.managementFeatureCreativeAccountingEffect,
    };

/// Übersetzt einen Feature-Schlüssel (`ManagementFeature.name`) in den
/// Anzeigenamen; unbekannte Schlüssel liefern `null`.
String? managementFeatureLabelFor(AppLocalizations l10n, String featureKey) {
  for (final feature in ManagementFeature.values) {
    if (feature.name == featureKey) return managementFeatureLabel(l10n, feature);
  }
  return null;
}
