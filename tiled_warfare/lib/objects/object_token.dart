
/// Enum der verfügbaren Kampfaktionen für eine Einheit.
///
/// Weitere Aktionen können in der Zukunft hinzugefügt werden.
enum CombatAction {
  /// Nahkampf-Angriff auf ein benachbartes Hex-Feld.
  melee,

  /// Fernkampf-Angriff auf ein Ziel in Reichweite.
  ranged,
}
class ObjectToken {
  final String name;
  final String imagePath;
  int woundValue;
  int attackValue;
  int defenseValue;
  int movementValue;
  int damageValue;
  int rangeValue;

  ObjectToken({
    required this.name,
    required this.imagePath,
    this.woundValue = 3,
    this.attackValue = 0,
    this.defenseValue = 0,
    this.movementValue = 0,
    this.damageValue = 1,
    this.rangeValue = 1,
  });
}
