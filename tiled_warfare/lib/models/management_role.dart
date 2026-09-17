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
