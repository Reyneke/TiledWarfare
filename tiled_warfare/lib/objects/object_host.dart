import 'dart:math';
import 'dart:ui' show Offset;

import 'package:tiled_warfare/fuzzy_logic/lib/fuzzylogic.dart';
import 'package:tiled_warfare/objects/object_dough_dumpster.dart';
import 'package:tiled_warfare/objects/object_dough_zombie.dart';
import 'package:tiled_warfare/objects/object_line_cook.dart';
import 'package:tiled_warfare/objects/object_player.dart';
import 'package:tiled_warfare/objects/object_token.dart';
import 'package:random_name_generator/random_name_generator.dart';

/// Repräsentiert ein Enneagramm-Persönlichkeitsprofil.
///
/// Die zwölf Enneagramme basieren auf der Enneagramm-Persönlichkeitstheorie
/// (siehe https://en.wikipedia.org/wiki/Enneagram_of_Personality).
/// Jedes Profil beeinflusst das Verhalten des Hosts im Spiel.
class EnneagramProfile {
  final String name;
  final String description;

  const EnneagramProfile(this.name, this.description);

  static const List<EnneagramProfile> all = [
    EnneagramProfile('Der Reformierte', 'Prinzipientreu, zielstrebig, perfektionistisch'),
    EnneagramProfile('Der Helfer', 'Fürsorglich, großzügig, besitzergreifend'),
    EnneagramProfile('Der Erfolgsorientierte', 'Ehrgeizig, anpassungsfähig, imagebewusst'),
    EnneagramProfile('Der Individualist', 'Kreativ, sensibel, selbstbezogen'),
    EnneagramProfile('Der Denker', 'Analytisch, zurückhaltend, geizig'),
    EnneagramProfile('Der Loyalist', 'Verantwortungsbewusst, misstrauisch, ängstlich'),
    EnneagramProfile('Der Enthusiast', 'Lebhaft, impulsiv, zerstreut'),
    EnneagramProfile('Der Herausforderer', 'Durchsetzungsfähig, beschützend, konfrontativ'),
    EnneagramProfile('Der Friedfertige', 'Ausgeglichen, bestätigend, träge'),
    EnneagramProfile('Der Stratege', 'Vorausschauend, berechnend, unnahbar'),
    EnneagramProfile('Der Beschützer', 'Mutig, territorial, stur'),
    EnneagramProfile('Der Chaot', 'Unberechenbar, kreativ, destruktiv'),
  ];
}

/// Fuzzy-Logik-basierte Persönlichkeitsbewertung für den Host.
///
/// Verwendet die Fuzzy Logic Systems library, um aus den aktuellen
/// Spielzuständen (z. B. Anzahl eigener Einheiten, Anzahl gegnerischer
/// Einheiten, Entfernung zum Gegner) eine Entscheidung über die
/// nächste Aktion des Hosts zu treffen.
class HostPersonality {
  final EnneagramProfile profile;

  /// Fuzzy-Variable für die Aggressivität (0 = defensiv, 100 = aggressiv).
  final Aggressiveness aggressiveness = Aggressiveness();

  /// Fuzzy-Variable für die Risikobereitschaft (0 = vorsichtig, 100 = risikofreudig).
  final RiskTolerance riskTolerance = RiskTolerance();

  /// Fuzzy-Variable für die Taktik (0 = direkt, 100 = komplex).
  final TacticalComplexity tacticalComplexity = TacticalComplexity();

  HostPersonality(this.profile);

  /// Initialisiert die Fuzzy-Regeln basierend auf dem Enneagramm-Profil.
  void initializeRules(FuzzyRuleBase ruleBase) {
    switch (profile.name) {
      case 'Der Herausforderer':
      case 'Der Chaot':
        // Aggressiv und risikofreudig
        ruleBase.addRules([
          (aggressiveness.Low) >> (aggressiveness.Medium),
          (riskTolerance.Low) >> (riskTolerance.High),
        ]);
        break;
      case 'Der Denker':
      case 'Der Stratege':
        // Defensiv und vorsichtig, aber taktisch komplex
        ruleBase.addRules([
          (aggressiveness.High) >> (aggressiveness.Medium),
          (riskTolerance.High) >> (riskTolerance.Low),
        ]);
        break;
      case 'Der Friedfertige':
      case 'Der Helfer':
        // Defensiv und vorsichtig
        ruleBase.addRules([
          (aggressiveness.High) >> (aggressiveness.Low),
          (riskTolerance.High) >> (riskTolerance.Low),
        ]);
        break;
      default:
        // Ausgeglichenes Verhalten
        ruleBase.addRules([
          (aggressiveness.Low) >> (aggressiveness.Medium),
          (aggressiveness.High) >> (aggressiveness.Medium),
        ]);
        break;
    }
  }
}

/// Fuzzy-Variable: Aggressivität (0–100).
class Aggressiveness extends FuzzyVariable<int> {
  var Low = FuzzySet.LeftShoulder(0, 25, 50);
  var Medium = FuzzySet.Triangle(25, 50, 75);
  var High = FuzzySet.RightShoulder(50, 75, 100);

  Aggressiveness() {
    sets = [Low, Medium, High];
    init();
  }
}

/// Fuzzy-Variable: Risikotoleranz (0–100).
class RiskTolerance extends FuzzyVariable<int> {
  var Low = FuzzySet.LeftShoulder(0, 25, 50);
  var Medium = FuzzySet.Triangle(25, 50, 75);
  var High = FuzzySet.RightShoulder(50, 75, 100);

  RiskTolerance() {
    sets = [Low, Medium, High];
    init();
  }
}

/// Fuzzy-Variable: Taktische Komplexität (0–100).
class TacticalComplexity extends FuzzyVariable<int> {
  var Direct = FuzzySet.LeftShoulder(0, 20, 40);
  var Balanced = FuzzySet.Triangle(20, 50, 80);
  var Complex = FuzzySet.RightShoulder(60, 80, 100);

  TacticalComplexity() {
    sets = [Direct, Balanced, Complex];
    init();
  }
}

/// Der Host ist sowohl für die Spieler als auch für die Gegner zuständig.
///
/// Er ist ein Singleton, da es nur eine Instanz des Hosts geben kann.
/// Der Host steuert die Gegner und ihre Einheiten. Er kann die Gegner in
/// Kämpfen gegen die Spieler einsetzen und ihre Fähigkeiten nutzen, um das
/// Spielziel zu erreichen.
///
/// Weiterhin ist er für die Einhaltung der Regeln verantwortlich, welche in
/// "combat_rules.md" definiert sind.
///
/// Um ihm eine Persönlichkeit zu geben, kann er mit einem Namen versehen
/// werden. Dieser Name wird in der GUI angezeigt, wenn der Host eine Aktion
/// ausführt. Weiterhin wählt er bei jedem Spielbeginn zufällig aus einem der
/// zwölf Enneagramme aus.
class ObjectHost {
  static final ObjectHost _instance = ObjectHost._internal();

  /// Gibt die einzige Instanz des Hosts zurück.
  factory ObjectHost() => _instance;

  ObjectHost._internal() {
    _initializePersonality();
  }

  /// Zufälliger Name für den Host.
  String name = RandomNames(Zone.us).fullName();

  /// Das zufällig gewählte Enneagramm-Profil des Hosts.
  late EnneagramProfile enneagramProfile;

  /// Die Fuzzy-Persönlichkeit des Hosts.
  late HostPersonality personality;

  /// Liste aller vom Host kontrollierten Dough Dumpster.
  List<ObjectDoughDumpster> doughDumpsterList = [];

  /// Zufallsgenerator.
  final Random _random = Random();

  /// Initialisiert die Persönlichkeit des Hosts.
  void _initializePersonality() {
    // Zufälliges Enneagramm auswählen
    enneagramProfile =
        EnneagramProfile.all[_random.nextInt(EnneagramProfile.all.length)];
    personality = HostPersonality(enneagramProfile);

    // Fuzzy-Regeln initialisieren
    final ruleBase = FuzzyRuleBase();
    personality.initializeRules(ruleBase);
  }

  /// Gibt den Host-Namen mit Enneagramm-Titel zurück (für GUI-Anzeige).
  String get displayName => '$name (${enneagramProfile.name})';

  // ──────────────────────────────────────────────
  // Dough Dumpster-Verwaltung
  // ──────────────────────────────────────────────

  /// Erzeugt einen neuen [ObjectDoughDumpster] und fügt ihn der
  /// [doughDumpsterList] hinzu. Gibt den neu erschaffenen Dumpster zurück.
  ObjectDoughDumpster spawnDoughDumpster() {
    final dumpster = ObjectDoughDumpster();
    doughDumpsterList.add(dumpster);
    return dumpster;
  }

  /// Entfernt einen [ObjectDoughDumpster] aus der [doughDumpsterList]
  /// (z. B. wenn er zerstört wurde).
  void removeDoughDumpster(ObjectDoughDumpster dumpster) {
    doughDumpsterList.remove(dumpster);
  }

  /// Gibt die Anzahl der aktuell kontrollierten Dough Dumpster zurück.
  int get doughDumpsterCount => doughDumpsterList.length;

  /// Gibt die Gesamtzahl aller Zombies aus allen Dough Dumpstern zurück.
  int get totalZombieCount {
    int count = 0;
    for (final dumpster in doughDumpsterList) {
      count += dumpster.zombieCount;
    }
    return count;
  }

  // ──────────────────────────────────────────────
  // Zombie-Verhalten
  // ──────────────────────────────────────────────

  /// Lässt alle Dough Dumpster Zombies spawnen.
  /// Gibt eine Liste aller neu erschaffenen Zombies zurück.
  List<ObjectDoughZombie> spawnAllZombies() {
    final List<ObjectDoughZombie> allNewZombies = [];
    for (final dumpster in doughDumpsterList) {
      allNewZombies.addAll(dumpster.spawnZombies());
    }
    return allNewZombies;
  }

  /// Bewegt alle Zombies auf die nächstgelegenen Line Cooks zu.
  ///
  /// Simuliert die gradlinige Bewegung der Dough Zombies auf Objekte vom
  /// Typ [ObjectLineCook]. Diese Methode sollte pro Spielzug aufgerufen
  /// werden.
  void moveAllZombiesTowardsLineCooks(List<ObjectLineCook> targets) {
    for (final dumpster in doughDumpsterList) {
      for (final zombie in dumpster.zombieList) {
        _moveZombieTowardsTarget(zombie, targets);
      }
    }
  }

  /// Bewegt einen einzelnen Zombie auf das nächste Ziel zu.
  void _moveZombieTowardsTarget(
      ObjectDoughZombie zombie, List<ObjectLineCook> targets) {
    if (targets.isEmpty) return;

    // Nächstgelegenes Ziel finden
    ObjectLineCook? nearestTarget;
    double nearestDistance = double.infinity;

    for (final target in targets) {
      final distance = (zombie.position - target.position).distance;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestTarget = target;
      }
    }

    if (nearestTarget == null) return;

    // Bewegung in Richtung des Ziels (vereinfacht: Bewegungspunkte nutzen)
    final dx = nearestTarget.position.dx - zombie.position.dx;
    final dy = nearestTarget.position.dy - zombie.position.dy;
    final distance = sqrt(dx * dx + dy * dy);

    if (distance > 0) {
      final moveDistance = zombie.movementValue.toDouble();
      final normalizedDx = (dx / distance) * moveDistance;
      final normalizedDy = (dy / distance) * moveDistance;

      zombie.position = Offset(
        zombie.position.dx + normalizedDx,
        zombie.position.dy + normalizedDy,
      );
    }
  }

  /// Führt Angriffe aller Zombies auf Line Cooks in Reichweite aus.
  ///
  /// Ein Zombie greift an (Nahkampf), wenn ein Line Cook in seiner Reichweite
  /// ist (rangeValue = 0 bedeutet Nahkampf, d. h. benachbarte Felder).
  /// Gemäß den Kampfregeln in "combat_rules.md".
  void performAllZombieAttacks(ObjectPlayer player) {
    for (final dumpster in doughDumpsterList) {
      final zombiesToRemove = <ObjectDoughZombie>[];

      for (final zombie in dumpster.zombieList) {
        // Kopie der Liste erstellen, da wir während der Iteration ggf.
        // Einträge entfernen müssen
        for (final cook in player.lineCookList.toList()) {
          final distance = (zombie.position - cook.position).distance;

          // Prüfen, ob der Line Cook in Reichweite ist
          if (distance <= zombie.rangeValue + 1) {
            final result = player.performAction(
              action: CombatAction.melee,
              attacker: zombie,
              defender: cook,
              distance: distance.round(),
            );

            // Zombie (Angreifer) wurde durch Patzer oder kritischen Erfolg
            // des Verteidigers verletzt
            if (zombie.woundValue <= 0) {
              zombiesToRemove.add(zombie);
              break; // Zombie ist tot, keine weiteren Angriffe
            }

            // Cook (Verteidiger) wurde getroffen und stirbt
            if (result.hit && cook.woundValue <= 0) {
              player.removeLineCook(cook);

              // 25% Chance: Zombie wird zu einem Dough Dumpster
              if (_random.nextInt(100) < 25) {
                spawnDoughDumpster();
              }
            }
          }
        }
      }

      // Tote Zombies entfernen
      for (final zombie in zombiesToRemove) {
        dumpster.removeZombie(zombie);
      }
    }
  }

  /// Verarbeitet den Tod eines Tokens, der von einem Zombie getötet wurde.
  ///
  /// Wenn ein Zombie einen Token des Spielers tötet, besteht eine 50% Chance,
  /// dass anstelle des Tokens ein weiterer Dough Zombie erscheint.
  void handleTokenKilledByZombie(ObjectDoughDumpster dumpster) {
    if (_random.nextInt(100) < 50) {
      final newZombie = ObjectDoughZombie();
      dumpster.zombieList.add(newZombie);
    }
  }

  // ──────────────────────────────────────────────
  // Kampfregeln
  // ──────────────────────────────────────────────

  /// Führt einen Initiative-Wurf für den Host durch.
  ///
  /// Gemäß den Kampfregeln (Abschnitt 7) wird zu Beginn jeder Runde für jede
  /// Seite ein Initiative-Wurf mit einem W100 durchgeführt.
  int rollInitiative() => _random.nextInt(100) + 1;

  /// Gibt die Anzahl der noch einsatzfähigen Einheiten des Hosts zurück.
  ///
  /// Gemäß Abschnitt 8 der Kampfregeln gilt der Host als besiegt, wenn alle
  /// seine Einheiten eine woundValue ≤ 0 haben.
  int get activeUnitCount {
    int count = 0;
    for (final dumpster in doughDumpsterList) {
      if (dumpster.woundValue > 0) count++;
      for (final zombie in dumpster.zombieList) {
        if (zombie.woundValue > 0) count++;
      }
    }
    return count;
  }

  /// Prüft, ob der Host besiegt wurde (alle Einheiten tot).
  bool get isDefeated => activeUnitCount == 0;
}
