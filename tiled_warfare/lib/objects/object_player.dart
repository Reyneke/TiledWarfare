import 'dart:math';

import 'package:tiled_warfare/objects/object_line_cook.dart';
import 'package:tiled_warfare/objects/object_token.dart';

/// Repräsentiert das Ergebnis eines Kampfangriffs.
class CombatResult {
  /// Ob der Angriff getroffen hat.
  final bool hit;

  /// Die Höhe des verursachten Schadens (0, wenn nicht getroffen).
  final int damage;

  /// Ob der Angreifer einen Patzer (Wurf > 90) erlitten hat.
  final bool attackerFumbled;

  /// Ob der Angreifer einen kritischen Erfolg (Wurf ≤ 5) erzielt hat.
  final bool attackerCritical;

  /// Ob der Verteidiger einen Patzer erlitten hat.
  final bool defenderFumbled;

  /// Ob der Verteidiger einen kritischen Erfolg erzielt hat.
  final bool defenderCritical;

  const CombatResult({
    required this.hit,
    required this.damage,
    this.attackerFumbled = false,
    this.attackerCritical = false,
    this.defenderFumbled = false,
    this.defenderCritical = false,
  });
}

/// Repräsentiert den Spieler und seine Einheiten.
///
/// Der Spieler steuert die Einheiten vom Typ [ObjectLineCook], die in der
/// Liste [lineCookList] gespeichert sind. Jede Einheit hat ihre eigenen
/// Eigenschaften wie Angriff, Verteidigung, Bewegung, Schaden und Reichweite.
///
/// Dieses Objekt ist ein Singleton, da es nur eine Instanz des Spielers geben
/// kann. Einheiten können im Laufe des Spiels verbessert und aufgerüstet werden.
///
/// Der Spieler kann seine Einheiten per Drag & Drop bewegen (siehe
/// [WidgetMapLoader]) und über ein Rechtsklick-Kontextmenü Aktionen wie
/// Nahkampf und Fernkampf ausführen.
class ObjectPlayer {
  static final ObjectPlayer _instance = ObjectPlayer._internal();

  /// Gibt die einzige Instanz des Spielers zurück.
  factory ObjectPlayer() => _instance;

  ObjectPlayer._internal();

  /// Liste aller vom Spieler kontrollierten Line Cooks.
  List<ObjectLineCook> lineCookList = [];

  /// Zufallsgenerator für Kampfwürfe.
  final Random _random = Random();

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

  /// Gibt die Liste der verfügbaren [CombatAction]s für eine Einheit zurück.
  ///
  /// Die Verfügbarkeit hängt von den Eigenschaften der Einheit ab:
  /// - "Nahkampf" (melee) ist immer verfügbar.
  /// - "Fernkampf" (ranged) ist nur verfügbar, wenn `rangeValue > 0`.
  List<CombatAction> getAvailableActions(ObjectLineCook cook) {
    final actions = <CombatAction>[CombatAction.melee];
    if (cook.rangeValue > 0) {
      actions.add(CombatAction.ranged);
    }
    return actions;
  }

  /// Führt einen W100-Wurf durch und gibt das Ergebnis (1–100) zurück.
  int _rollD100() => _random.nextInt(100) + 1;

  /// Führt einen Angriff mit der angegebenen [action] vom [attacker] auf den
  /// [defender] aus.
  ///
  /// Verwendet die Kampfregeln aus `doc/rules/combat_rules.md`:
  /// - Jeder Wurf verwendet einen W100 (Ergebnis 1–100).
  /// - Ein Wurf gilt als Erfolg, wenn das Ergebnis ≤ dem geforderten Wert ist.
  /// - Ein Wurf > 90 ist ein Patzer.
  /// - Ein Wurf ≤ 5 ist ein kritischer Erfolg.
  ///
  /// Gibt ein [CombatResult] mit dem Ergebnis des Angriffs zurück.
  CombatResult performAction({
    required CombatAction action,
    required ObjectLineCook attacker,
    required ObjectToken defender,
    int distance = 1,
  }) {
    final int effectiveAttackValue;
    final int effectiveDefenseValue = defender.defenseValue;

    // Angriffswert basierend auf der Aktion und Entfernung bestimmen
    if (action == CombatAction.ranged) {
      // Fernkampf: Entfernungsmalus gemäß combat_rules.md
      if (distance <= attacker.rangeValue * 0.5) {
        effectiveAttackValue = attacker.attackValue; // kein Malus
      } else if (distance <= attacker.rangeValue * 0.75) {
        effectiveAttackValue = attacker.attackValue - 10; // −10 Malus
      } else {
        effectiveAttackValue = attacker.attackValue - 20; // −20 Malus
      }
    } else {
      // Nahkampf: nur auf benachbarte Felder möglich
      effectiveAttackValue = attacker.attackValue;
    }

    // Angreifer würfelt
    final attackRoll = _rollD100();
    final bool attackSuccess = attackRoll <= effectiveAttackValue;
    final bool attackFumble = attackRoll > 90;
    final bool attackCritical = attackRoll <= 5;

    // Verteidiger würfelt
    final defenseRoll = _rollD100();
    final bool defenseSuccess = defenseRoll <= effectiveDefenseValue;
    final bool defenseFumble = defenseRoll > 90;
    final bool defenseCritical = defenseRoll <= 5;

    // Ergebnisbestimmung gemäß combat_rules.md
    if (attackFumble) {
      // Patzer Angreifer: Angreifer erleidet automatisch Schaden
      final selfDamage = (defender.damageValue / 2).ceil();
      attacker.woundValue -= selfDamage;
      return CombatResult(
        hit: false,
        damage: 0,
        attackerFumbled: true,
        defenderFumbled: defenseFumble,
        attackerCritical: false,
        defenderCritical: defenseCritical,
      );
    }

    if (defenseCritical) {
      // Kritischer Erfolg Verteidiger: kein Schaden, Angreifer erleidet halben Schaden
      final counterDamage = (defender.damageValue / 2).ceil();
      attacker.woundValue -= counterDamage;
      return CombatResult(
        hit: false,
        damage: 0,
        attackerFumbled: false,
        defenderFumbled: defenseFumble,
        attackerCritical: attackCritical,
        defenderCritical: true,
      );
    }

    if (attackCritical) {
      // Kritischer Erfolg Angreifer: doppelter Schaden
      final doubleDamage = attacker.damageValue * 2;
      defender.woundValue -= doubleDamage;
      return CombatResult(
        hit: true,
        damage: doubleDamage,
        attackerFumbled: false,
        defenderFumbled: defenseFumble,
        attackerCritical: true,
        defenderCritical: false,
      );
    }

    if (defenseFumble) {
      // Patzer Verteidiger: doppelter Schaden
      final doubleDamage = attacker.damageValue * 2;
      defender.woundValue -= doubleDamage;
      return CombatResult(
        hit: true,
        damage: doubleDamage,
        attackerFumbled: false,
        defenderFumbled: true,
        attackerCritical: false,
        defenderCritical: false,
      );
    }

    if (!attackSuccess) {
      // Angreifer verfehlt
      return CombatResult(
        hit: false,
        damage: 0,
        attackerFumbled: false,
        defenderFumbled: defenseFumble,
        attackerCritical: false,
        defenderCritical: false,
      );
    }

    // Beide haben gewürfelt – Vergleichswert berechnen
    final int attackerComparison = effectiveAttackValue - attackRoll;
    final int defenderComparison = effectiveDefenseValue - defenseRoll;

    if (!defenseSuccess || attackerComparison > defenderComparison) {
      // Angreifer trifft
      defender.woundValue -= attacker.damageValue;
      return CombatResult(
        hit: true,
        damage: attacker.damageValue,
        attackerFumbled: false,
        defenderFumbled: defenseFumble,
        attackerCritical: false,
        defenderCritical: false,
      );
    } else if (attackerComparison == defenderComparison) {
      // Gleichstand → Münzwurf (W100 > 51 → Angreifer gewinnt)
      final coinToss = _rollD100();
      if (coinToss > 51) {
        defender.woundValue -= attacker.damageValue;
        return CombatResult(
          hit: true,
          damage: attacker.damageValue,
          attackerFumbled: false,
          defenderFumbled: defenseFumble,
          attackerCritical: false,
          defenderCritical: false,
        );
      } else {
        return CombatResult(
          hit: false,
          damage: 0,
          attackerFumbled: false,
          defenderFumbled: defenseFumble,
          attackerCritical: false,
          defenderCritical: false,
        );
      }
    } else {
      // Verteidiger verteidigt erfolgreich
      return CombatResult(
        hit: false,
        damage: 0,
        attackerFumbled: false,
        defenderFumbled: defenseFumble,
        attackerCritical: false,
        defenderCritical: false,
      );
    }
  }
}
