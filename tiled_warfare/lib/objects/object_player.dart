import 'dart:math';
import 'package:tiled_warfare/objects/player_objects/object_apprentice.dart';
import 'package:tiled_warfare/objects/player_objects/object_line_cook.dart';
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

/// Repräsentiert das Ergebnis eines FocusFire-Angriffs.
class FocusFireResult {
  /// Liste der Ergebnisse der einzelnen Angriffe.
  final List<({ObjectToken attacker, CombatResult result})> attacks;

  /// Gesamtschaden, der dem Ziel zugefügt wurde.
  final int totalDamage;

  const FocusFireResult({
    required this.attacks,
    required this.totalDamage,
  });
}

/// Repräsentiert den Spieler und seine Einheiten.
///
/// Der Spieler steuert die Einheiten vom Typ [ObjectApprentice] (und deren
/// Unterklassen wie [ObjectLineCook]), die in der Liste [unitList] gespeichert
/// sind. Jede Einheit hat ihre eigenen Eigenschaften wie Angriff, Verteidigung,
/// Bewegung, Schaden und Reichweite.
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

  /// Liste aller vom Spieler kontrollierten Einheiten (nur Überlebende).
  List<ObjectApprentice> unitList = [];

  /// Vollständige Liste aller Einheiten, die in die aktuelle Schlacht
  /// mitgenommen wurden (inkl. gefallener). Wird beim Aufruf von
  /// [ObjectProfile.selectTeamForBattle] befüllt und dient dem
  /// Ergebnis-Bildschirm zur korrekten Auflistung aller Teilnehmer.
  List<ObjectApprentice> battleRoster = [];

  /// Zufallsgenerator für Kampfwürfe.
  final Random _random = Random();

  /// Erzeugt einen neuen [ObjectLineCook] und fügt ihn der [unitList] hinzu.
  /// Gibt den neu erschaffenen Line Cook zurück.
  ObjectLineCook spawnLineCook() {
    final cook = ObjectLineCook();
    unitList.add(cook);
    return cook;
  }

  /// Entfernt eine [ObjectApprentice]-Einheit aus der [unitList]
  /// (z. B. wenn sie zerstört wurde).
  void removeUnit(ObjectApprentice unit) {
    unitList.remove(unit);
  }

  /// Gibt die Anzahl der aktuell kontrollierten Einheiten zurück.
  int get unitCount => unitList.length;

  /// Verbessert die Eigenschaften einer [ObjectApprentice]-Einheit.
  ///
  /// Nur übergebene Werte werden aktualisiert; `null`-Werte bleiben unverändert.
  void upgradeUnit(
    ObjectApprentice unit, {
    int? attackValue,
    int? defenseValue,
    int? movementValue,
    int? damageValue,
    int? rangeValue,
    int? woundValue,
  }) {
    if (attackValue != null) unit.attackValue = attackValue;
    if (defenseValue != null) unit.defenseValue = defenseValue;
    if (movementValue != null) unit.movementValue = movementValue;
    if (damageValue != null) unit.damageValue = damageValue;
    if (rangeValue != null) unit.rangeValue = rangeValue;
    if (woundValue != null) unit.woundValue = woundValue;
  }

  /// Gibt die Liste der verfügbaren [CombatAction]s für eine Einheit zurück.
  ///
  /// Die Verfügbarkeit hängt von den Eigenschaften der Einheit ab:
  /// - "Nahkampf" (melee) ist immer verfügbar (solange die Einheit noch nicht gehandelt hat).
  /// - "Fernkampf" (ranged) ist nur verfügbar, wenn `rangeValue > 0`.
  /// - "FocusFire" (focusFire) ist nur verfügbar, wenn noch keine Aktion ausgeführt wurde.
  ///
  /// Einheiten, die bereits gehandelt haben (hasActed == true), erhalten keine Kampfaktionen.
  List<CombatAction> getAvailableActions(ObjectApprentice unit) {
    final actions = <CombatAction>[];
    // Nur Aktionen anbieten, wenn die Einheit noch nicht gehandelt hat
    if (!unit.hasActed) {
      actions.add(CombatAction.melee);
      if (unit.rangeValue > 0) {
        actions.add(CombatAction.ranged);
      }
      // FocusFire ist verfügbar, solange die Einheit noch nicht gehandelt hat
      actions.add(CombatAction.focusFire);
    }
    return actions;
  }

  /// Führt einen Initiative-Wurf für den Spieler durch.
  ///
  /// Gemäß den Kampfregeln (Abschnitt 7) wird zu Beginn jeder Runde für jede
  /// Seite ein Initiative-Wurf mit einem W100 durchgeführt.
  int rollInitiative() => _random.nextInt(100) + 1;

  /// Führt einen W100-Wurf durch und gibt das Ergebnis (1–100) zurück.
  int _rollD100() => _random.nextInt(100) + 1;

  /// Berechnet den effektiven Angriffswert unter Berücksichtigung von
  /// Entfernungsmalus und dem kumulativen Angriffs-Bonus gegen das Ziel.
  ///
  /// Der Angriffs-Bonus ergibt sich aus der Anzahl der Angriffe,
  /// die auf das Ziel in dieser Runde bereits ausgeführt wurden (+5 % pro Angriff).
  int _calculateEffectiveAttackValue({
    required CombatAction action,
    required ObjectToken attacker,
    required ObjectToken defender,
    required int distance,
  }) {
    int effectiveAttackValue;

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

    // Kumulativen Angriffs-Bonus durch mehrfache Angriffe auf das Ziel anwenden
    // Jeder vorherige Angriff auf den Verteidiger gibt +5 % auf den Angriffswert
    effectiveAttackValue += defender.attackBonus;

    return effectiveAttackValue.clamp(0, 100);
  }

  /// Berechnet den effektiven Verteidigungswert unter Berücksichtigung des
  /// kumulativen Verteidigungs-Malus durch mehrfache Angriffe.
  ///
  /// Der Malus beträgt −5 % pro Angriff auf diesen Token in dieser Runde.
  int _calculateEffectiveDefenseValue(ObjectToken defender) {
    // Kumulativen Verteidigungs-Malus durch mehrfache Angriffe anwenden
    // Jeder Angriff auf den Verteidiger gibt −5 % auf den Verteidigungswert
    final effectiveDefenseValue = defender.defenseValue - defender.defenseMalus;
    return effectiveDefenseValue.clamp(0, 100);
  }

  /// Führt einen Angriff mit der angegebenen [action] vom [attacker] auf den
  /// [defender] aus.
  ///
  /// Verwendet die Kampfregeln aus `doc/rules/combat_rules.md`:
  /// - Jeder Wurf verwendet einen W100 (Ergebnis 1–100).
  /// - Ein Wurf gilt als Erfolg, wenn das Ergebnis ≤ dem geforderten Wert ist.
  /// - Ein Wurf > 90 ist ein Patzer.
  /// - Ein Wurf ≤ 5 ist ein kritischer Erfolg.
  ///
  /// Berücksichtigt den kumulativen Malus/Bonus für mehrfach angegriffene Tokens
  /// (siehe `doc/todo/6_Kleine_Dinge.md`, Punkt 9):
  /// - Der Verteidiger erleidet −5 % Verteidigung pro bereits erfolgtem Angriff.
  /// - Der Angreifer erhält +5 % Angriff pro bereits erfolgtem Angriff auf das Ziel.
  ///
  /// Wichtig: Der [defender.timesAttackedThisTurn]-Zähler wird **nach** der
  /// Kampfberechnung erhöht, sodass der aktuelle Angriff noch mit den Werten
  /// vor diesem Angriff abgewickelt wird. Nachfolgende Angriffe in derselben
  /// Runde profitieren dann vom erhöhten Malus/Bonus.
  ///
  /// Gibt ein [CombatResult] mit dem Ergebnis des Angriffs zurück.
  CombatResult performAction({
    required CombatAction action,
    required ObjectToken attacker,
    required ObjectToken defender,
    int distance = 1,
  }) {
    // Effektive Werte unter Berücksichtigung des Malus-Systems berechnen
    final int effectiveAttackValue = _calculateEffectiveAttackValue(
      action: action,
      attacker: attacker,
      defender: defender,
      distance: distance,
    );
    final int effectiveDefenseValue = _calculateEffectiveDefenseValue(defender);

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
    final CombatResult result = _resolveCombat(
      attacker: attacker,
      defender: defender,
      effectiveAttackValue: effectiveAttackValue,
      effectiveDefenseValue: effectiveDefenseValue,
      attackRoll: attackRoll,
      attackSuccess: attackSuccess,
      attackFumble: attackFumble,
      attackCritical: attackCritical,
      defenseRoll: defenseRoll,
      defenseSuccess: defenseSuccess,
      defenseFumble: defenseFumble,
      defenseCritical: defenseCritical,
    );

    // Kumulativen Malus-Zähler für den Verteidiger erhöhen.
    // Dies geschieht NACH der Kampfberechnung, sodass der aktuelle Angriff
    // noch ohne diesen Zähler abgewickelt wird. Nachfolgende Angriffe in
    // derselben Runde profitieren dann vom erhöhten Malus.
    defender.timesAttackedThisTurn++;

    return result;
  }

  /// Kern der Kampfberechnung: Bestimmt das [CombatResult] anhand der
  /// Würfelergebnisse und der geltenden Regeln (Patzer, Kritische Erfolge,
  /// Vergleichswert-System).
  ///
  /// Ausgelagert aus [performAction] zur besseren Lesbarkeit und Testbarkeit.
  CombatResult _resolveCombat({
    required ObjectToken attacker,
    required ObjectToken defender,
    required int effectiveAttackValue,
    required int effectiveDefenseValue,
    required int attackRoll,
    required bool attackSuccess,
    required bool attackFumble,
    required bool attackCritical,
    required int defenseRoll,
    required bool defenseSuccess,
    required bool defenseFumble,
    required bool defenseCritical,
  }) {
    // 1. Spezialfälle vor der normalen Kampfberechnung prüfen
    // (Patzer des Angreifers, kritische Erfolge)
    if (attackFumble) {
      return _handleAttackerFumble(attacker, defender, defenseFumble, defenseCritical);
    }
    if (defenseCritical) {
      return _handleDefenderCritical(attacker, defender, attackCritical, defenseFumble);
    }
    if (attackCritical) {
      return _handleAttackerCritical(attacker, defender, defenseFumble);
    }
    if (defenseFumble) {
      return _handleDefenderFumble(attacker, defender);
    }
    if (!attackSuccess) {
      return _handleMiss(defenseFumble);
    }

    // 2. Normaler Kampf: Beide haben bestanden – Vergleichswert entscheidet
    return _resolveNormalCombat(
      attacker: attacker,
      defender: defender,
      effectiveAttackValue: effectiveAttackValue,
      effectiveDefenseValue: effectiveDefenseValue,
      attackRoll: attackRoll,
      defenseRoll: defenseRoll,
      defenseSuccess: defenseSuccess,
      defenseFumble: defenseFumble,
    );
  }

  /// Patzer des Angreifers (Wurf > 90): Angreifer erleidet selbst Schaden.
  CombatResult _handleAttackerFumble(
    ObjectToken attacker,
    ObjectToken defender,
    bool defenseFumble,
    bool defenseCritical,
  ) {
    final selfDamage = (defender.damageValue / 2).ceil();
    attacker.woundValue -= selfDamage;
    return CombatResult(
      hit: false,
      damage: 0,
      attackerFumbled: true,
      defenderFumbled: defenseFumble,
      defenderCritical: defenseCritical,
    );
  }

  /// Kritischer Erfolg des Verteidigers (Wurf ≤ 5):
  /// Angriff abgewehrt, Angreifer erleidet halben Schaden.
  CombatResult _handleDefenderCritical(
    ObjectToken attacker,
    ObjectToken defender,
    bool attackCritical,
    bool defenseFumble,
  ) {
    final counterDamage = (defender.damageValue / 2).ceil();
    attacker.woundValue -= counterDamage;
    return CombatResult(
      hit: false,
      damage: 0,
      attackerCritical: attackCritical,
      defenderCritical: true,
      defenderFumbled: defenseFumble,
    );
  }

  /// Kritischer Erfolg des Angreifers (Wurf ≤ 5):
  /// Automatischer Treffer mit doppeltem Schaden.
  CombatResult _handleAttackerCritical(
    ObjectToken attacker,
    ObjectToken defender,
    bool defenseFumble,
  ) {
    final doubleDamage = attacker.damageValue * 2;
    defender.woundValue -= doubleDamage;
    return CombatResult(
      hit: true,
      damage: doubleDamage,
      attackerCritical: true,
      defenderFumbled: defenseFumble,
    );
  }

  /// Patzer des Verteidigers (Wurf > 90):
  /// Automatischer Treffer mit doppeltem Schaden.
  CombatResult _handleDefenderFumble(ObjectToken attacker, ObjectToken defender) {
    final doubleDamage = attacker.damageValue * 2;
    defender.woundValue -= doubleDamage;
    return CombatResult(
      hit: true,
      damage: doubleDamage,
      defenderFumbled: true,
    );
  }

  /// Angreifer verfehlt (Wurf über effektivem Angriffswert).
  CombatResult _handleMiss(bool defenseFumble) {
    return CombatResult(
      hit: false,
      damage: 0,
      defenderFumbled: defenseFumble,
    );
  }

  /// Normaler Kampf: Beide haben ihre Würfe bestanden.
  /// Der Vergleichswert (effektiver Wert − Wurf) entscheidet, wer gewinnt.
  CombatResult _resolveNormalCombat({
    required ObjectToken attacker,
    required ObjectToken defender,
    required int effectiveAttackValue,
    required int effectiveDefenseValue,
    required int attackRoll,
    required int defenseRoll,
    required bool defenseSuccess,
    required bool defenseFumble,
  }) {
    final int attackerComparison = effectiveAttackValue - attackRoll;
    final int defenderComparison = effectiveDefenseValue - defenseRoll;

    if (!defenseSuccess || attackerComparison > defenderComparison) {
      // Angreifer trifft
      defender.woundValue -= attacker.damageValue;
      return CombatResult(
        hit: true,
        damage: attacker.damageValue,
        defenderFumbled: defenseFumble,
      );
    }

    if (attackerComparison == defenderComparison) {
      // Gleichstand → Münzwurf (W100 > 51 → Angreifer gewinnt)
      final coinToss = _rollD100();
      if (coinToss > 51) {
        defender.woundValue -= attacker.damageValue;
        return CombatResult(
          hit: true,
          damage: attacker.damageValue,
          defenderFumbled: defenseFumble,
        );
      }
    }

    // Verteidiger verteidigt erfolgreich
    return CombatResult(
      hit: false,
      damage: 0,
      defenderFumbled: defenseFumble,
    );
  }

  /// Führt eine FocusFire-Aktion aus: Alle verfügbaren Angreifer greifen
  /// das gemeinsame Ziel an.
  ///
  /// [attackers] ist die Liste der Angreifer, die gegen das Ziel angreifen sollen.
  /// Jeder Angreifer muss in Reichweite sein und darf in dieser Runde noch nicht
  /// gehandelt haben.
  ///
  /// Jeder Angreifer wählt automatisch die beste verfügbare Aktion:
  /// - Nahkampf (melee), wenn der Gegner benachbart ist (distance <= 1)
  /// - Fernkampf (ranged), wenn der Gegner in Fernkampf-Reichweite liegt
  /// - Der Angreifer wird übersprungen, wenn keine Reichweite gegeben ist
  ///
  /// Der Parameter [action] dient nur als Fallback und wird pro Angreifer
  /// durch die beste Aktion ersetzt.
  ///
  /// Gibt ein [FocusFireResult] mit den Ergebnissen aller Einzelangriffe zurück.
  FocusFireResult performFocusFire({
    required List<ObjectToken> attackers,
    required ObjectToken defender,
    required CombatAction action,
    required int Function(ObjectToken attacker) getDistance,
  }) {
    final attackResults = <({ObjectToken attacker, CombatResult result})>[];
    int totalDamage = 0;

    for (final attacker in attackers) {
      // Überspringe tote Angreifer
      if (attacker.woundValue <= 0) continue;

      // Überspringe Angreifer, die bereits gehandelt haben
      if (attacker.hasActed) continue;

      final distance = getDistance(attacker);

      // Beste Aktion für diesen Angreifer wählen:
      // - Nahkampf (melee), wenn das Ziel benachbart ist (distance <= 1)
      // - Fernkampf (ranged), wenn das Ziel in Fernkampf-Reichweite liegt
      // - Sonst: Angreifer überspringen
      CombatAction bestAction;
      if (distance <= 1) {
        bestAction = CombatAction.melee;
      } else if (attacker.rangeValue > 0 && distance <= attacker.rangeValue) {
        bestAction = CombatAction.ranged;
      } else {
        continue; // Angreifer ist außer Reichweite
      }

      final result = performAction(
        action: bestAction,
        attacker: attacker,
        defender: defender,
        distance: distance,
      );

      // Angreifer als "hat gehandelt" markieren
      attacker.hasActed = true;

      if (result.hit) {
        totalDamage += result.damage;
      }

      attackResults.add((attacker: attacker, result: result));
    }

    return FocusFireResult(
      attacks: attackResults,
      totalDamage: totalDamage,
    );
  }

  /// Setzt den [timesAttackedThisTurn]-Zähler für alle Einheiten zurück.
  /// Wird zu Beginn jedes Zuges der kontrollierenden Seite aufgerufen.
  void resetAttackCounters() {
    for (final unit in unitList) {
      unit.timesAttackedThisTurn = 0;
    }
  }
}