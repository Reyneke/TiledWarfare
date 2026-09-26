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

  /// Sabotage – „Charmantes Lächeln, rasiermesserscharfe Nägel“ (Chefsekretärin,
  /// `11a` E14): externe Kräfte greifen ein **Rivalen-Restaurant** an
  /// (`13_Gegner_Restaurants.md`, Minimal-Modul V11). Das Ziel ist eine
  /// Rivalen-ID (`StaffEntryData.featureTargetId`); die Auflösung erfolgt im
  /// Wochen-Tick (deterministischer Erfolgswurf, Erfolg ⇒ befristeter
  /// Einkommens-Bonus und Prestige-Malus des Rivalen, Misserfolg ⇒ Strafe).
  sabotage,

  /// Winkelzug – (Rechtsanwalt, `11a` E15): mildert eine **eintreffende Strafe**
  /// während des aktiven Fensters; die Höhe skaliert mit der Kompetenz des
  /// Trägers (bis zur vollständigen Negation).
  legalTrick,

  /// Kreative Buchführung – (Buchhalter, `11a` E16): negiert befristet **alle**
  /// laufenden Kosten; danach fällt der Träger für dieselbe Dauer aus
  /// (Burnout = Nachteilphase).
  creativeAccounting,
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
