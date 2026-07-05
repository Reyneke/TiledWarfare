
import 'dart:ui' show Offset;

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
  int moneyValue;
  int xpValue;

  /// Pixel-Position des Tokens auf der Karte (x, y).
  /// Wird gesetzt, sobald der Token auf der Karte platziert wird.
  Offset position = Offset.zero;

  /// Ob der Token in der aktuellen Runde bereits eine Kampfaktion ausgeführt hat.
  /// Wird zu Beginn jeder Runde zurückgesetzt.
  bool hasActed = false;

  ObjectToken({
    required this.name,
    required this.imagePath,
    this.woundValue = 3,
    this.attackValue = 0,
    this.defenseValue = 0,
    this.movementValue = 0,
    this.damageValue = 1,
    this.rangeValue = 1,
    this.moneyValue = 100,
    this.xpValue = 25,
  });
}
