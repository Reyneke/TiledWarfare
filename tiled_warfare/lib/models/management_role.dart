import 'package:tiled_warfare/models/management_feature.dart';

/// Verwaltungs-/Marketing-Rollen (Kategorie `RoleKind.management`, Option C, `11a`).
///
/// Diese Rollen sind **kein** Kampfpersonal und **keine** Küchenbrigade (siehe
/// `SupportRole`). Sie wirken auf die Management-Schleife und werden wie die
/// übrigen Nicht-Kampf-Rollen über den gemeinsamen Anstell-Contract verwaltet
/// (`StaffEntryData`, `StaffRoleService`).
enum ManagementRole {
  /// Social Media Manager – verwaltet die Außenwirkung/Marketing.
  ///
  /// Die konkrete Wirkung ist in `11a` noch offen (Entscheidung **E3**);
  /// die Balance liefert deshalb bislang nur den Wochenlohn.
  socialMediaManager,
}

/// Alle Verwaltungs-/Marketing-Rollen in Anzeige-Reihenfolge.
const List<ManagementRole> kAllManagementRoles = ManagementRole.values;

/// Bildet einen persistierten Rollen-Schlüssel (`ManagementRole.name`) ab;
/// unbekannt oder `null` → `null` (tolerante Deserialisierung, V6).
ManagementRole? managementRoleFromName(String? roleKey) {
  if (roleKey == null) return null;
  for (final role in ManagementRole.values) {
    if (role.name == roleKey) return role;
  }
  return null;
}

/// Das **aktive Feature** einer Verwaltungs-/Marketing-Rolle – oder `null`,
/// wenn die Rolle keines besitzt (Option C, `11a`).
///
/// Die Rollen-Zuordnung ist Teil des Datenmodells, die Wirkung liegt in
/// `ManagementFeatureService`/`EconomyBalance`.
ManagementFeature? managementFeatureOf(ManagementRole role) => switch (role) {
      ManagementRole.socialMediaManager => ManagementFeature.prCampaign,
    };
