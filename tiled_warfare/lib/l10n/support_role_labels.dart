import 'package:tiled_warfare/l10n/app_localizations.dart';
import 'package:tiled_warfare/models/support_role.dart';

/// Übersetzt eine Hilfs-/Service-Rolle in den lokalisierten Namen
/// (Karrierepfade, V10, Phase 6).
String supportRoleLabel(AppLocalizations l10n, SupportRole role) =>
    switch (role) {
      SupportRole.communard => l10n.supportRoleCommunard,
      SupportRole.tournant => l10n.supportRoleTournant,
      SupportRole.aboyeur => l10n.supportRoleAboyeur,
      SupportRole.plongeur => l10n.supportRolePlongeur,
      SupportRole.commis => l10n.supportRoleCommis,
      SupportRole.boucher => l10n.supportRoleBoucher,
      SupportRole.garcon => l10n.supportRoleGarcon,
    };

/// Kurzbeschreibung der Wirkung einer Hilfs-/Service-Rolle (V10, Phase 6).
String supportRoleEffectLabel(AppLocalizations l10n, SupportRole role) =>
    switch (role) {
      SupportRole.communard => l10n.supportRoleEffectCommunard,
      SupportRole.tournant => l10n.supportRoleEffectTournant,
      SupportRole.aboyeur => l10n.supportRoleEffectAboyeur,
      SupportRole.plongeur => l10n.supportRoleEffectPlongeur,
      SupportRole.commis => l10n.supportRoleEffectCommis,
      SupportRole.boucher => l10n.supportRoleEffectBoucher,
      SupportRole.garcon => l10n.supportRoleEffectGarcon,
    };

/// Übersetzt einen Rollen-Schlüssel (`SupportRole.name`) in den Anzeigenamen;
/// unbekannte Schlüssel liefern `null`.
String? supportRoleLabelFor(AppLocalizations l10n, String roleKey) {
  for (final role in SupportRole.values) {
    if (role.name == roleKey) return supportRoleLabel(l10n, role);
  }
  return null;
}
