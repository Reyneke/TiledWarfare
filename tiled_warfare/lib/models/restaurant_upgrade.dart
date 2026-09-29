/// Erweiterungstypen des Restaurants (§ 10).
///
/// Die konkreten Balance-Werte (Maximalstufe, Ankauf-/Erhalt-Basis, Boni)
/// liegen zentral in `EconomyBalance.upgrades` (V7).
enum UpgradeType {
  /// Mehr Tische – Kapazität & Kundenzufriedenheit.
  tables,

  /// Größere Küche – Kapazität.
  kitchen,

  /// Werbeplakate – Attraktivität.
  signage,

  /// Dekorationen – Attraktivität & Kundenzufriedenheit.
  decoration,

  /// Musikautomat – Attraktivität (Einzelstufe).
  jukebox,

  /// Wein-/Getränkekeller – Kundenzufriedenheit & Attraktivität.
  ///
  /// V1-Paket aus § 10 (`11b_Restauranterweiterungen.md`, Gruppe A): schließt die
  /// Zufriedenheits-Lücke und ist die **Wirkungsbasis des Sommeliers** (`11a`,
  /// Plongeur-Muster – die Rolle wird erst mit gebautem Keller wertvoll).
  cellar,

  /// Kühlhaus/Kühlkette – Kapazität.
  ///
  /// V1-Paket aus § 10 (`11b_Restauranterweiterungen.md`, Gruppe B): verbreitert
  /// die **Kapazitäts-Basis**, die der **Lagerist** (`11a`, V12) bzw. ein aktives
  /// „Lagertetris“ faktorbasiert vervielfacht („additiv statt Multiplikator“).
  /// Wirkt **nur skalierend**: ohne Personal ist die Kapazität ohnehin `0`
  /// (`GameClockService.capacityOf`) – der Baustein erzeugt keine Basis.
  coldRoom,

  /// Erste-Hilfe-Station – Heilzeit pro Verletzungsstufe.
  ///
  /// V1-Paket aus § 10 (`11b_Restauranterweiterungen.md`, Gruppe B, **⚙-Hook**):
  /// verkürzt die Echtzeit-Heilung je Verletzungsstufe prozentual. Der Baustein
  /// hängt an `GameClockService.healTimePerStageFor` und wirkt damit auf **alle**
  /// Konsumenten gleichzeitig (`advanceHealing`, `rollBackEmergencyShots`,
  /// `remainingHealingTime` der UI).
  ///
  /// **Entschiedene Wirkungs-Option:** −5 % Heilzeit je Stufe (nicht der
  /// alternativ diskutierte „+1 Rettungswurf-Zielwert“): Der Rettungswurf ist
  /// bereits das Alleinstellungsmerkmal des **Teamarztes**
  /// (`EconomyBalance.medicQualitySpecs[…].survivalBonus`), während die Heilzeit
  /// bis dahin **ungehebelt** war. Die Heilzeit wirkt zudem deterministisch,
  /// ständig sichtbar (jede Verletzung, jeder Catch-up) und über die gesamte
  /// Heilungskette (`dying → … → ready`), statt nur beim seltenen
  /// Gefechts-Todeswurf. Die prozentuale Verkürzung **multipliziert** die vom
  /// Teamarzt gesetzte Basiszeit (24 h ohne Arzt; 6 h/3 h/1 h nach Qualität) –
  /// kein Doppel-Hebel, weil die Rolle die Basis *setzt* und die Erweiterung
  /// sie nur verkürzt.
  firstAid,

  /// Ruheraum/Lounge – Wochen-Refill & Tages-Sink der Personal-Ressourcen.
  ///
  /// V1-Paket aus § 10 (`11b_Restauranterweiterungen.md`, Gruppe B, **⚙-Hook**):
  /// entlastet das Personal doppelt – er hebt den **Wochen-Refill** von
  /// Vitalität/Moral (+3 %/Stufe) und senkt den **Tages-Sink** (−3 %/Stufe).
  ///
  /// **Entschiedene Wirkungs-Option:** beide Effekte („und“, wie in der
  /// Tabellen-Zeile). Die Hooks liegen an den beiden bestehenden Stellen im
  /// Catch-up: `_refillStaffResources` (Blockende) und `_applyDailyResourceSink`
  /// (Tagesschritt). Der Refill-Bonus ist ein **Gebäude-Effekt** und gilt darum
  /// **allen** Charakteren (anders als der Pâtissier, der sich von seiner eigenen
  /// Wirkung ausnimmt).
  ///
  /// **Abgrenzung:** Die Sink-Seite senkt ausschließlich den **Tages-Sink**; der
  /// **Erschöpfungs-Malus** der Nulltage (`_probeResources`) bleibt dem
  /// **Tournant** vorbehalten. Der Sink-Hebel ist zudem bewusst ein
  /// **Stacking-/Situations-Hebel**: Bei einem Tages-Sink von `5` und Rundung
  /// pro Tag wird eine reine „−3 %/Stufe“ erst in Kombination sichtbar (mit dem
  /// Gewerkschaftschef additiv, oder in der Nachteilphase eines Features mit
  /// Sink-Faktor `2`). Das Plongeur-Muster – „der Baustein wird erst mit der
  /// Rolle wertvoll“ – ist hier bewusst gewollt.
  lounge,
}

/// Balance-Definition einer Restaurant-Erweiterung (§ 10).
///
/// Alle Kosten skalieren **linear mit der Stufe**: Der Ausbau **auf** Stufe `N`
/// kostet `buyBaseCost × N`; der wöchentliche Unterhalt **auf** Stufe `N`
/// beträgt `upkeepBaseCostPerWeek × N`. Kumulativ bis Stufe `N` sind
/// `buyBaseCost × N·(N+1)/2` investiert.
class UpgradeSpec {
  /// Maximale Ausbaustufe.
  final int maxLevel;

  /// Ankauf-Basis pro Stufe (Kosten zum Erreichen von Stufe `N` = Basis × N).
  final int buyBaseCost;

  /// Erhalt-Basis pro Woche und Stufe (Unterhalt auf Stufe `N` = Basis × N).
  final int upkeepBaseCostPerWeek;

  /// Kapazitäts-Bonus pro Stufe (relativ, z. B. 0.05 = +5 %).
  final double capacityBonusPerLevel;

  /// Attraktivitäts-Bonus pro Stufe (relativ).
  final double attractivenessBonusPerLevel;

  /// Kundenzufriedenheits-Bonus pro Stufe (relativ).
  final double satisfactionBonusPerLevel;

  /// Verkürzung der Heilzeit pro Verletzungsstufe je Stufe (relativ, z. B.
  /// `0.05` = −5 %). Anders als die drei Eingangswert-Boni wirkt sie **nicht**
  /// über `upgradeEffects` auf Attraktivität/Zufriedenheit/Kapazität, sondern
  /// als Faktor auf `GameClockService.healTimePerStageFor` (§ 10, `firstAid`).
  final double healTimeReductionPerLevel;

  /// Erhöhung des Wochen-Refill-Ziels für Vitalität/Moral je Stufe (relativ,
  /// z. B. `0.03` = +3 %). Wirkt **nicht** über die drei Eingangswerte, sondern
  /// am Blockende auf den Refill (`GameClockService._refillStaffResources`,
  /// § 10, `lounge`).
  final double refillBonusPerLevel;

  /// Senkung des **Tages-Sinks** (Vitalität/Moral) je Stufe (relativ, z. B.
  /// `0.03` = −3 %). Wirkt am Tagesschritt (`GameClockService`
  /// `_applyDailyResourceSink`, § 10, `lounge`); der Erschöpfungs-Malus der
  /// Nulltage bleibt unberührt.
  final double dailySinkReliefPerLevel;

  const UpgradeSpec({
    required this.maxLevel,
    required this.buyBaseCost,
    required this.upkeepBaseCostPerWeek,
    this.capacityBonusPerLevel = 0.0,
    this.attractivenessBonusPerLevel = 0.0,
    this.satisfactionBonusPerLevel = 0.0,
    this.healTimeReductionPerLevel = 0.0,
    this.refillBonusPerLevel = 0.0,
    this.dailySinkReliefPerLevel = 0.0,
  });
}
