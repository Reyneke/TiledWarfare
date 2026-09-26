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

  /// Rush Hour – (Oberkellner, V12): hebt befristet **alle drei Eingangswerte**
  /// des passiven Einkommens (Attraktivität, Zufriedenheit, Kapazität) um
  /// `rushHourInputBonusPercent`; währenddessen fallen die **Mali** weg
  /// (Tages-Sink und Erschöpfungs-Malus). Die dafür anfallende Erschöpfung wird
  /// **anteilig nach Ranghöhe** auf das anwesende Personal verteilt („von oben
  /// herab“): je mehr Mitarbeiter, desto geringer die Last des Einzelnen.
  rushHour,

  /// Organisation ist alles – (Personalchef, V12): senkt befristet den Verlust
  /// körperlicher wie geistiger Stabilität (Tages-Sink −
  /// `organisationSinkReductionPercent`). Die Reduktion wird **mit Geld
  /// bezahlt**: `organisationCostPerDay` je aktivem Tag (als `featureCosts`).
  organisationIsEverything,

  /// Lagertetris – (Lagerist, V12): vervielfacht die Kapazität für einen
  /// Wochentick um `storageTetrisCapacityFactorPerCompetence` je Kompetenz-
  /// Stufe; **alle Mali** (Tages-Sink und Erschöpfungs-Malus) fallen dabei weg.
  /// Die Einmalkosten skalieren mit der Kompetenz
  /// (`storageTetrisCostPerCompetence`).
  storageTetris,

  /// „Alle Räder …“ – (Gewerkschaftschef, V12): erlaubt es, **mehr als einen**
  /// Mitarbeiter auf Sabotagemission zu schicken
  /// (`ManagementFeatureService.sabotageTeamSize`: 1 + Kompetenz). Die
  /// `shadiness` aller Beteiligten wird **gemittelt** (Erfolgs-Bonus), die aus
  /// dem Auftrag resultierende Erschöpfung ebenso; je weiteres Teammitglied
  /// gibt es einen **Reroll**, wenn ein Wurf scheitert.
  unionWorkers,

  /// „Rache ist Blutwurst“ – (Sicherheitschef, V13): schlägt **reaktiv** gegen
  /// einen in der eigenen Stadtteil-Sabotage **entdeckten** Angreifer zurück
  /// (`13_Gegner_Restaurants.md`, Minimal-Modul V13).
  ///
  /// Das Feature ist **ziel-los**: Es wird für ein Wochenfenster scharf
  /// geschaltet (`featureActivatedAt`). Trifft in diesem Fenster ein entdeckter
  /// Sabotageversuch eines Rivalen ein, wird **höchstens ein** Gegenschlag
  /// ausgeführt (`featureResolvedAt` als Idempotenz-Marker); bleibt das Fenster
  /// ohne entdeckten Angriff, verfällt es einfach. Ausführender ist die
  /// angestellte Chefsekretärin (falls vorhanden, ohne Mutation ihrer Felder)
  /// oder eine deterministisch rekrutierte Mannschaft aus dem Kampfpersonal.
  counterSabotage,
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
