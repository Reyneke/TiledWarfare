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

  /// Chefsekretärin – senkt laufende Mitarbeiter- und
  /// Erweiterungs-Anschaffungskosten (binär, `11a` E12).
  ///
  /// Trägt das Feature **Sabotage** („Charmantes Lächeln, rasiermesserscharfe
  /// Nägel“, E14): externe Kräfte führen einen Angriff auf ein Rivalen-Restaurant
  /// aus (`13_Gegner_Restaurants.md`).
  chefSecretary,

  /// Rechtsanwalt – senkt erlittene Strafen (binär, `11a` E12).
  ///
  /// Trägt das Feature **Winkelzug** (E15): mildert eine während des Fensters
  /// eintreffende Strafe – bei hoher Kompetenz bis zur Negation.
  lawyer,

  /// Buchhalter – senkt alle laufenden Kosten (binär, `11a` E12).
  ///
  /// Trägt das Feature **Kreative Buchführung** (E16): negiert befristet alle
  /// laufenden Kosten und fällt danach (Burnout) aus.
  accountant,

  /// Oberkellner – hebt Attraktivität und Kapazität (V12).
  ///
  /// Trägt das Feature **Rush Hour** (V12): befristeter Schub auf alle drei
  /// Eingangswerte des passiven Einkommens, Mali entfallen – bezahlt mit
  /// rangverteilter Erschöpfung.
  headWaiter,

  /// Personalchef – hebt Kundenzufriedenheit und Kapazität (V12).
  ///
  /// Trägt das Feature **Organisation ist alles** (V12): befristet stark
  /// reduzierter Stabilitätsverlust; die Reduktion wird mit Geld bezahlt.
  personnelManager,

  /// Lagerist – hoher Kapazitäts-Bonus (V12).
  ///
  /// Trägt das Feature **Lagertetris** (V12): vervielfacht die Kapazität für
  /// einen Wochentick; alle Mali fallen weg.
  storekeeper,

  /// Gewerkschaftschef – hebt die Mitarbeiterkosten, senkt dafür deren
  /// Erschöpfung (V12).
  ///
  /// Trägt das Feature **„Alle Räder …“** (V12): mehr als ein Mitarbeiter auf
  /// Sabotagemission, gemittelte `shadiness`/Erschöpfung und ein Reroll je
  /// zusätzlichem Teammitglied.
  unionChief,

  /// Sicherheitschef – hebt die **Entdeckung** eingehender Sabotageversuche
  /// (V13).
  ///
  /// Passiv: Die Entdeckungswahrscheinlichkeit steigt mit der Kompetenz des
  /// Trägers (`securityChiefDetectionBonusPercentPerCompetence`), zusätzlich
  /// zählt die durchschnittliche `shadiness` des Personals
  /// (`RivalService.incomingDetectionPercent`).
  ///
  /// Trägt das Feature **„Rache ist Blutwurst“** (V13): ein befristet
  /// scharfgeschalteter, **reaktiver** Gegenschlag gegen einen in diesem
  /// Fenster **entdeckten** Angreifer.
  securityChief,
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
  ManagementRole.chefSecretary => ManagementFeature.sabotage,
  ManagementRole.lawyer => ManagementFeature.legalTrick,
  ManagementRole.accountant => ManagementFeature.creativeAccounting,
  ManagementRole.headWaiter => ManagementFeature.rushHour,
  ManagementRole.personnelManager => ManagementFeature.organisationIsEverything,
  ManagementRole.storekeeper => ManagementFeature.storageTetris,
  ManagementRole.unionChief => ManagementFeature.unionWorkers,
  ManagementRole.securityChief => ManagementFeature.counterSabotage,
};
