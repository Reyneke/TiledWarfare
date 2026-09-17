import 'package:tiled_warfare/l10n/app_localizations.dart';
import 'package:tiled_warfare/models/management_role.dart';

/// Übersetzt eine Verwaltungs-/Marketing-Rolle in den lokalisierten Namen
/// (Option C, `11a`).
String managementRoleLabel(AppLocalizations l10n, ManagementRole role) =>
    switch (role) {
      ManagementRole.socialMediaManager => l10n.managementRoleSocialMediaManager,
    };

/// Kurzbeschreibung der Wirkung einer Verwaltungs-/Marketing-Rolle
/// (Option C, `11a`).
String managementRoleEffectLabel(AppLocalizations l10n, ManagementRole role) =>
    switch (role) {
      ManagementRole.socialMediaManager =>
        l10n.managementRoleEffectSocialMediaManager,
    };

/// Übersetzt einen Rollen-Schlüssel (`ManagementRole.name`) in den Anzeigenamen;
/// unbekannte Schlüssel liefern `null`.
String? managementRoleLabelFor(AppLocalizations l10n, String roleKey) {
  for (final role in ManagementRole.values) {
    if (role.name == roleKey) return managementRoleLabel(l10n, role);
  }
  return null;
}
