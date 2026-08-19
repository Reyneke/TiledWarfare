import 'package:tiled_warfare/models/map_data.dart';
import 'package:tiled_warfare/models/sector.dart';

/// Standardname der Objektebene "Sektoren" in Tiled.
const String kSectorGroupName = 'Sektoren';

/// Parst die **"Sektoren"**-Objektebene.
///
/// Unterstützt:
/// - Rechteck-Objekte (x, y, width, height)
/// - Polygon-Objekte (`points`) – absolute Punkte werden übernommen
/// - Punkt-Objekte (width == 0 && height == 0)
///
/// Jedes Objekt wird zu einem [Sector] mit Name, Geometrie und Properties.
///
/// [sectorGroup] – Die Objektgruppe mit dem Namen "Sektoren".
///                 Kann `null` sein (→ leere Liste).
///
/// Gibt eine Liste aller geparsten Sektoren zurück.
List<Sector> parseSectors(ObjectGroup? sectorGroup) {
  if (sectorGroup == null) return const [];

  return [
    for (final obj in sectorGroup.objects)
      Sector(
        name: obj.name,
        x: obj.x,
        y: obj.y,
        width: obj.width,
        height: obj.height,
        // Polygon-Offsets werden in absolute Punkte umgerechnet
        points: obj.absolutePoints,
        properties: Map<String, dynamic>.from(obj.properties),
      ),
  ];
}

/// Sucht die "Sektoren"-Objektebene in den Objektgruppen der Karte.
///
/// Gibt `null` zurück, wenn keine Objektebene mit dem Namen "Sektoren"
/// existiert (die Karte nutzt dann keine Sektoren).
ObjectGroup? findSectorGroup(List<ObjectGroup> objectGroups) {
  for (final group in objectGroups) {
    if (group.name == kSectorGroupName) return group;
  }
  return null;
}