import 'package:tiled_warfare/objects/object_line_cook.dart';

/// Repräsentiert den Spieler und seine Einheiten.
///
/// Der Spieler steuert die Einheiten vom Typ [ObjectLineCook], die in der
/// Liste [lineCookList] gespeichert sind. Jede Einheit hat ihre eigenen
/// Eigenschaften wie Angriff, Verteidigung, Bewegung, Schaden und Reichweite.
///
/// Dieses Objekt ist ein Singleton, da es nur eine Instanz des Spielers geben
/// kann. Einheiten können im Laufe des Spiels verbessert und aufgerüstet werden.
class ObjectPlayer {
  static final ObjectPlayer _instance = ObjectPlayer._internal();

  /// Gibt die einzige Instanz des Spielers zurück.
  factory ObjectPlayer() => _instance;

  ObjectPlayer._internal();

  /// Liste aller vom Spieler kontrollierten Line Cooks.
  List<ObjectLineCook> lineCookList = [];

  /// Erzeugt einen neuen [ObjectLineCook] und fügt ihn der [lineCookList] hinzu.
  /// Gibt den neu erschaffenen Line Cook zurück.
  ObjectLineCook spawnLineCook() {
    final cook = ObjectLineCook();
    lineCookList.add(cook);
    return cook;
  }

  /// Entfernt einen [ObjectLineCook] aus der [lineCookList]
  /// (z. B. wenn er zerstört wurde).
  void removeLineCook(ObjectLineCook cook) {
    lineCookList.remove(cook);
  }

  /// Gibt die Anzahl der aktuell kontrollierten Line Cooks zurück.
  int get lineCookCount => lineCookList.length;

  /// Verbessert die Eigenschaften eines [ObjectLineCook].
  ///
  /// Nur übergebene Werte werden aktualisiert; `null`-Werte bleiben unverändert.
  void upgradeLineCook(
    ObjectLineCook cook, {
    int? attackValue,
    int? defenseValue,
    int? movementValue,
    int? damageValue,
    int? rangeValue,
    int? woundValue,
  }) {
    if (attackValue != null) cook.attackValue = attackValue;
    if (defenseValue != null) cook.defenseValue = defenseValue;
    if (movementValue != null) cook.movementValue = movementValue;
    if (damageValue != null) cook.damageValue = damageValue;
    if (rangeValue != null) cook.rangeValue = rangeValue;
    if (woundValue != null) cook.woundValue = woundValue;
  }
}
