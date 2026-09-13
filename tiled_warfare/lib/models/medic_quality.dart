/// Qualitätsstufen des Teamarztes (Identität).
///
/// Die zugehörigen Balance-Werte (Kostenmultiplikator, Rettungswurf-Bonus,
/// Heilzeit pro Stufe) liegen **nicht** hier, sondern zentral in
/// `EconomyBalance.medicQualitySpecs` (V7,
/// `doc/todo/feat_better_restaurant_management/7_Wirtschaftswerte_zentralisieren.md`).
enum MedicQuality {
  /// Günstig, geringer Bonus auf Rettungswürfe und Heilung.
  niedrig,

  /// Mittelklasse, solider Bonus.
  mittel,

  /// Hochwertig, maximale Boni.
  hoch,
}
