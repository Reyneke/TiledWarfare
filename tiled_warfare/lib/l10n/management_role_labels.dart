import 'package:tiled_warfare/l10n/app_localizations.dart';
import 'package:tiled_warfare/models/management_role.dart';

/// Übersetzt eine Verwaltungs-/Marketing-Rolle in den lokalisierten Namen
/// (Option C, `11a`).
String managementRoleLabel(AppLocalizations l10n, ManagementRole role) =>
    switch (role) {
      ManagementRole.socialMediaManager =>
        l10n.managementRoleSocialMediaManager,
      ManagementRole.chefSecretary => l10n.managementRoleChefSecretary,
      ManagementRole.lawyer => l10n.managementRoleLawyer,
      ManagementRole.accountant => l10n.managementRoleAccountant,
      ManagementRole.headWaiter => l10n.managementRoleHeadWaiter,
      ManagementRole.personnelManager => l10n.managementRolePersonnelManager,
      ManagementRole.storekeeper => l10n.managementRoleStorekeeper,
      ManagementRole.unionChief => l10n.managementRoleUnionChief,
      ManagementRole.securityChief => l10n.managementRoleSecurityChief,
    };

/// Kurzbeschreibung der Wirkung einer Verwaltungs-/Marketing-Rolle
/// (Option C, `11a`).
String managementRoleEffectLabel(AppLocalizations l10n, ManagementRole role) =>
    switch (role) {
      ManagementRole.socialMediaManager =>
        l10n.managementRoleEffectSocialMediaManager,
      ManagementRole.chefSecretary => l10n.managementRoleEffectChefSecretary,
      ManagementRole.lawyer => l10n.managementRoleEffectLawyer,
      ManagementRole.accountant => l10n.managementRoleEffectAccountant,
      ManagementRole.headWaiter => l10n.managementRoleEffectHeadWaiter,
      ManagementRole.personnelManager =>
        l10n.managementRoleEffectPersonnelManager,
      ManagementRole.storekeeper => l10n.managementRoleEffectStorekeeper,
      ManagementRole.unionChief => l10n.managementRoleEffectUnionChief,
      ManagementRole.securityChief => l10n.managementRoleEffectSecurityChief,
    };

/// Übersetzt einen Rollen-Schlüssel (`ManagementRole.name`) in den Anzeigenamen;
/// unbekannte Schlüssel liefern `null`.
String? managementRoleLabelFor(AppLocalizations l10n, String roleKey) {
  for (final role in ManagementRole.values) {
    if (role.name == roleKey) return managementRoleLabel(l10n, role);
  }
  return null;
}
