
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

/// Basis-Klasse für alle Tokens (Einheiten) auf der Karte.
///
/// Ein Token repräsentiert eine einzelne Einheit – egal ob Spieler-Charakter,
/// Monster oder Boss. Jeder Token hat einen Namen, ein Bild, eine Pixel-Position
/// auf der Karte sowie Kampfstatistiken.
///
/// Die Eigenschaften orientieren sich an den Kampfregeln aus `doc/rules/combat_rules.md`:
///
/// | Eigenschaft      | Entsprechung in combat_rules.md |
/// |------------------|----------------------------------|
/// | [attackValue]    | Angriffswert (W100-Zielwert)     |
/// | [defenseValue]   | Verteidigungswert (W100-Zielwert)|
/// | [damageValue]    | Schadenswert bei Treffer         |
/// | [woundValue]     | Trefferpunkte (Gesundheit)       |
/// | [movementValue]  | Maximale Bewegung pro Zug        |
/// | [rangeValue]     | Reichweite für Fernkampf         |
///
/// Siehe auch: [ObjectApprentice] (Spieler-Charaktere),
/// [ObjectDoughZombie] (Standard-Gegner).
class ObjectToken {
  /// Anzeigename des Tokens (z. B. "Luigi Rossi").
  String name;

  /// Relativer Pfad zum Token-Bild (z. B. "assets/images/token/token_cook_basic.png").
  String imagePath;

  /// Aktuelle Trefferpunkte (Wundstufen).
  ///
  /// Bei [ObjectToken]: Gesundheitspunkte im Kampf (≤ 0 = tot).
  /// Bei [ObjectApprentice]: Zusätzlich Verletzungs-Status über [ObjectApprentice.status].
  int woundValue;

  /// Angriffswert – W100-Zielwert für Angriffswürfe (0–100).
  ///
  /// Gemäß combat_rules.md Abschnitt 2: Ein Wurf ist erfolgreich,
  /// wenn das Ergebnis ≤ diesem Wert ist.
  int attackValue;

  /// Verteidigungswert – W100-Zielwert für Verteidigungswürfe (0–100).
  int defenseValue;

  /// Maximale Bewegung in Hex-Feldern pro Zug.
  int movementValue;

  /// Schadenswert – Höhe des Schadens, den dieser Token bei einem Treffer verursacht.
  int damageValue;

  /// Reichweite für Fernkampf-Angriffe in Hex-Feldern.
  /// 0 oder 1 bedeutet reiner Nahkampf.
  int rangeValue;

  /// Geldwert, den dieser Token bei Besiegung gewährt.
  int moneyValue;

  /// Erfahrungspunkte, die dieser Token bei Besiegung gewährt.
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

  /// Erzeugt eine Kopie dieses Tokens mit optional geänderten Werten.
  ObjectToken copyWith({
    String? name,
    String? imagePath,
    int? woundValue,
    int? attackValue,
    int? defenseValue,
    int? movementValue,
    int? damageValue,
    int? rangeValue,
    int? moneyValue,
    int? xpValue,
    Offset? position,
    bool? hasActed,
  }) {
    return ObjectToken(
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      woundValue: woundValue ?? this.woundValue,
      attackValue: attackValue ?? this.attackValue,
      defenseValue: defenseValue ?? this.defenseValue,
      movementValue: movementValue ?? this.movementValue,
      damageValue: damageValue ?? this.damageValue,
      rangeValue: rangeValue ?? this.rangeValue,
      moneyValue: moneyValue ?? this.moneyValue,
      xpValue: xpValue ?? this.xpValue,
    );
  }
}
