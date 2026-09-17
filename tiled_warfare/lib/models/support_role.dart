/// Hilfs- und Service-Rollen der Küchenbrigade (Karrierepfade, V10, Phase 6).
///
/// Diese Rollen bündeln **keine** Kampfklassen: Sie ziehen nicht ins Gefecht,
/// sondern wirken auf die Management-Schleife (Einkommen, Refill, Kosten) und
/// werden wie die Teamärzte auf der Personal-Seite verwaltet. Die
/// Wirkungswerte liegen in `EconomyBalance`, die Auswertung in
/// `SupportRoleService`.
enum SupportRole {
  /// Staff cook – verbessert den Wochen-Refill von Vitalität und Moral.
  communard,

  /// Roundsman – senkt den Erschöpfungs-Malus der Nulltage.
  tournant,

  /// Expediter – verbessert den Bestellfluss (Kunden/Woche).
  aboyeur,

  /// Dishwasher/porter – senkt die laufenden Betriebskosten.
  plongeur,

  /// Busser – leicht positiver Attraktivitäts-Effekt.
  commis,

  /// Butcher – wirkt auf Nachschub/Beute.
  boucher,

  /// Kitchen boy – kleiner Bonus auf die Management-Werte.
  garcon,
}

/// Alle Hilfs-/Service-Rollen in Anzeige-Reihenfolge.
const List<SupportRole> kAllSupportRoles = SupportRole.values;
