/// Küchenstationen der Brigade (Karrierepfade, V10).
///
/// Eine **Station** ist die horizontale Spezialisierung eines
/// `Chef de partie` (und höher): kein eigener Rang, sondern ein Bündel aus
/// Modifikatoren (inkl. Aura). Die Schlüssel sind stabil und dienen als
/// Persistenz-Werte in `StaffData.station` – niemals der Anzeigename.
///
/// Die Definition lebt bewusst in einer eigenen Datei ohne Importe, damit
/// sowohl `EconomyBalance` (Tuning) als auch `ObjectApprentice` (Laufzeit)
/// darauf zugreifen können, ohne einen Import-Zyklus zu erzeugen.
library;

/// Basis-Stationen (ohne Varianten).
const String kStationSaucier = 'saucier';
const String kStationPoissonnier = 'poissonnier';
const String kStationRotisseur = 'rotisseur';
const String kStationEntremetier = 'entremetier';
const String kStationGardeManger = 'garde_manger';
const String kStationPatissier = 'patissier';

/// Varianten (Unterränge der Referenztabelle) – ersetzen den Bonus der Basis,
/// sobald die Basis-Station gewählt wurde (kein Stapeln).
const String kStationGrillardin = 'grillardin';
const String kStationFriturier = 'friturier';
const String kStationPotager = 'potager';
const String kStationLegumier = 'legumier';
const String kStationCharcutier = 'charcutier';

/// Alle wählbaren Stationen – Basis zuerst, danach die Varianten.
const List<String> kBaseStations = [
  kStationSaucier,
  kStationPoissonnier,
  kStationRotisseur,
  kStationEntremetier,
  kStationGardeManger,
  kStationPatissier,
];

/// Alle Varianten-Stationen (nur nach Wahl ihrer Basis-Station wählbar).
const List<String> kVariantStations = [
  kStationGrillardin,
  kStationFriturier,
  kStationPotager,
  kStationLegumier,
  kStationCharcutier,
];

/// Alle Stationen (Basis + Varianten).
const List<String> kAllStations = [...kBaseStations, ...kVariantStations];

/// Art eines Stations-Bonus – ordnet einen Prozentwert der passenden
/// Kenngröße zu (Angriff, Verteidigung, Schaden, Reichweite).
enum StationStat { attack, defense, damage, range }
