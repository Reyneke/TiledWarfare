/// Aktive Sonderfertigkeiten („Features“) spezieller Nicht-Kampf-Mitarbeiter
/// (Option C, `11a`).
///
/// Features sind **keine** passiven Rollen-Effekte: Sie werden aktiv ausgelöst,
/// kosten einmalig Geld, wirken über ein befristetes Zeitfenster und hinterlassen
/// eine Nachteilphase. Sie docken damit an denselben Verwaltungs-Contract an
/// (`StaffEntryData`, `StaffRoleService`), bleiben aber eine eigene Mechanik.
enum ManagementFeature {
  /// PR-Kampagne – befristeter XP-Boost für ein Teammitglied (Social Media
  /// Manager). Kosten, Fenster und Nachteilphase liegen in `EconomyBalance`,
  /// die Auswertung in `ManagementFeatureService`.
  prCampaign,
}

/// Alle Features in Anzeige-Reihenfolge.
const List<ManagementFeature> kAllManagementFeatures = ManagementFeature.values;

/// Bildet einen persistierten Feature-Namen ab (unbekannt → `null`).
ManagementFeature? managementFeatureFromName(String? name) {
  if (name == null) return null;
  for (final value in ManagementFeature.values) {
    if (value.name == name) return value;
  }
  return null;
}
