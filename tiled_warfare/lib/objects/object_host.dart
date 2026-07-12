import 'dart:math';
import 'dart:ui' show Offset;

import 'package:tiled_warfare/fuzzy_logic/lib/fuzzylogic.dart';
import 'package:tiled_warfare/objects/boss_monsters/object_dough_dumpster.dart';
import 'package:tiled_warfare/objects/monsters/object_dough_zombie.dart';
import 'package:tiled_warfare/objects/player_objects/object_appretice.dart';
import 'package:tiled_warfare/objects/player_objects/object_line_cook.dart';
import 'package:tiled_warfare/objects/object_player.dart';
import 'package:tiled_warfare/objects/object_token.dart';
import 'package:random_name_generator/random_name_generator.dart';

/// Konstante Tile-Größe für die Hex-Gitter-Berechnung (aus der TMX-Datei).
const int _hostTileWidth = 32;
const int _hostTileHeight = 32;

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
  void moveAllZombiesTowardsTargets(List<ObjectApprentice> targets) {
    for (final dumpster in doughDumpsterList) {
      for (final zombie in dumpster.zombieList) {
        _moveZombieTowardsTarget(zombie, targets);
      }
    }
  }

  /// Rechnet Pixel-Koordinaten in die nächstgelegenen Hex-Gitter-Koordinaten
  /// (x, y) um (odd-r staggerindex="odd").
  /// Gleiche Logik wie in WidgetCaretaker.
  ({int x, int y}) _pixelToHex(Offset pixel) {
    final approxY = (pixel.dy / (_hostTileHeight * 3.0 / 4.0)).round();
    int x;
    if (approxY % 2 == 1) {
      x = ((pixel.dx - _hostTileWidth / 2) / _hostTileWidth).round();
    } else {
      x = (pixel.dx / _hostTileWidth).round();
    }
    return (x: x, y: approxY);
  }

  /// Rechnet Hex-Gitter-Koordinaten (x, y) in Pixel-Koordinaten um
  /// (odd-r staggerindex="odd").
  Offset _hexToPixel({required int x, required int y}) {
    final double pixelX;
    if (y % 2 == 1) {
      pixelX = (x * _hostTileWidth).toDouble() + _hostTileWidth / 2;
    } else {
      pixelX = (x * _hostTileWidth).toDouble();
    }
    final pixelY = y * (_hostTileHeight * 3.0 / 4.0);
    return Offset(pixelX, pixelY);
  }

  /// Bewegt einen einzelnen Zombie auf das nächste Ziel zu.
  /// Die Bewegung erfolgt hexgitter-basiert: Der Zombie rückt genau ein
  /// Hex-Feld in Richtung des Ziels vor und rastet auf dem Hex-Zentrum ein.
  /// Überspringt belegte Hex-Felder, um Stapelung zu vermeiden.
  void _moveZombieTowardsTarget(
      ObjectDoughZombie zombie, List<ObjectApprentice> targets) {
    if (targets.isEmpty) return;

    // Nächstgelegenes Ziel finden
    ObjectApprentice? nearestTarget;
    double nearestDistance = double.infinity;

    for (final target in targets) {
      final distance = (zombie.position - target.position).distance;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestTarget = target;
      }
    }

    if (nearestTarget == null) return;

    // Hex-Koordinaten des Zombies und des Ziels ermitteln
    final zombieHex = _pixelToHex(zombie.position);
    final targetHex = _pixelToHex(nearestTarget.position);

    // Differenz in Hex-Koordinaten berechnen
    final dx = targetHex.x - zombieHex.x;
    final dy = targetHex.y - zombieHex.y;

    // Wenn Zombie und Ziel auf dem gleichen Hex-Feld sind, nichts tun
    if (dx == 0 && dy == 0) return;

    // Alle aktuell belegten Hex-Felder ermitteln (außer dem Zombie selbst),
    // inklusive der Spieler-Einheiten, damit Zombies nicht auf ihnen stacken
    final occupied = _buildOccupiedHostHexes(playerUnits: targets);
    // Entferne den Zombie selbst aus der belegten-Menge, damit er sich
    // von seinem eigenen Feld wegbewegen kann
    occupied.remove(zombieHex.y * 100 + zombieHex.x);

    // Schrittweite = min(1, movementValue) Hex-Felder
    // Zombies movementValue = 1, also genau 1 Schritt
    final steps = zombie.movementValue.clamp(1, 100);

    // Hex-Richtung wählen: bevorzuge die Achse mit der größten Differenz
    int newHexX = zombieHex.x;
    int newHexY = zombieHex.y;

    for (int step = 0; step < steps; step++) {
      // Nächsten Schritt bestimmen:
      // Wir bewegen uns in eine der 6 Hex-Richtungen (odd-r).
      // Bevorzuge die Richtung, die uns dem Ziel am nächsten bringt.
      final currentX = newHexX;
      final currentY = newHexY;

      // Nachbarn für aktuelles y (gerade/ungerade)
      final neighbors = (currentY % 2 == 0)
          ? [(-1, -1), (0, -1), (-1, 0), (1, 0), (-1, 1), (0, 1)]
          : [(0, -1), (1, -1), (-1, 0), (1, 0), (0, 1), (1, 1)];

      // Den Nachbarn mit der geringsten Entfernung zum Ziel wählen,
      // der nicht belegt ist
      ({int dx, int dy}) bestNeighbor = (dx: 0, dy: 0);
      int bestDistance = 999999;

      for (final (ndx, ndy) in neighbors) {
        final nx = currentX + ndx;
        final ny = currentY + ndy;
        if (nx < 0 || ny < 0) continue; // Kartenränder überspringen

        // Belegte Felder überspringen (Kollisionsvermeidung)
        if (occupied.contains(ny * 100 + nx)) continue;

        final dist = ((targetHex.x - nx).abs() + (targetHex.y - ny).abs());
        if (dist < bestDistance) {
          bestDistance = dist;
          bestNeighbor = (dx: ndx, dy: ndy);
        }
      }

      if (bestNeighbor.dx == 0 && bestNeighbor.dy == 0) break;

      newHexX += bestNeighbor.dx;
      newHexY += bestNeighbor.dy;
    }

    // Auf Hex-Zentrum setzen
    zombie.position = _hexToPixel(x: newHexX, y: newHexY);
  }

  /// Führt Angriffe aller Zombies auf Line Cooks in Reichweite aus.
  ///
  /// Ein Zombie greift an (Nahkampf), wenn ein Line Cook in seiner Reichweite
  /// ist (rangeValue = 0 bedeutet Nahkampf, d. h. benachbarte Felder).
  /// Gemäß den Kampfregeln in "combat_rules.md".
  ///
  /// Gibt eine Liste von Log-Nachrichten zurück, die im UI angezeigt werden können.
  List<String> performAllZombieAttacks(ObjectPlayer player) {
    final logMessages = <String>[];

    // Puffer für neue Dumpster, die während der Kampfiteration erstellt werden,
    // um ConcurrentModificationError zu vermeiden.
    final newDumpsters = <ObjectDoughDumpster>[];

    for (final dumpster in doughDumpsterList) {
      final zombiesToRemove = <ObjectDoughZombie>[];
      // Puffer für neue Zombies, die durch handleTokenKilledByZombie erstellt werden,
      // um ConcurrentModificationError beim Iterieren von zombieList zu vermeiden.
      final newZombiesPending = <ObjectDoughZombie>[];

      for (final zombie in dumpster.zombieList) {
        // Kopie der Liste erstellen, da wir während der Iteration ggf.
        // Einträge entfernen müssen
        for (final cook in player.unitList.toList()) {
          // Hex-Entfernung zwischen Zombie und Ziel ermitteln
          final zombieHex = _pixelToHex(zombie.position);
          final cookHex = _pixelToHex(cook.position);
          final hexDistance = (zombieHex.x - cookHex.x).abs() + (zombieHex.y - cookHex.y).abs();

          // Prüfen, ob der Line Cook in Reichweite ist (Nahkampf = benachbarte Hex-Felder)
          if (hexDistance <= zombie.rangeValue + 1) {
            final distance = (zombie.position - cook.position).distance;
            final result = player.performAction(
              action: CombatAction.melee,
              attacker: zombie,
              defender: cook,
              distance: distance.round(),
            );

            // Log-Nachricht für diesen Angriff erstellen
            String logEntry = '${zombie.name} greift ${cook.name} an: ';
            if (result.hit) {
              logEntry += 'Treffer! ${result.damage} Schaden.';
            } else {
              logEntry += 'Verfehlt!';
            }
            if (result.attackerCritical) logEntry += ' (Kritischer Treffer!)';
            if (result.attackerFumbled) logEntry += ' (Patzer!)';
            if (result.defenderCritical) logEntry += ' (Gegner pariert kritisch!)';
            if (result.defenderFumbled) logEntry += ' (Gegner patzt!)';
            logMessages.add(logEntry);

            // Zombie (Angreifer) wurde durch Patzer oder kritischen Erfolg
            // des Verteidigers verletzt
            if (zombie.woundValue <= 0) {
              logMessages.add('${zombie.name} wurde getötet!');
              zombiesToRemove.add(zombie);
              break; // Zombie ist tot, keine weiteren Angriffe
            }

            // Cook (Verteidiger) wurde getroffen und stirbt
            if (result.hit && cook.woundValue <= 0) {
              logMessages.add('${cook.name} wurde getötet!');
              player.removeUnit(cook);

              // Wenn ein Zombie einen Token des Spielers tötet, besteht eine 50% Chance,
              // dass anstelle des Tokens ein weiterer Dough Zombie erscheint.
              // Zombie wird gepuffert und nach der Iteration hinzugefügt.
              if (_random.nextInt(100) < 50) {
                final newZombie = ObjectDoughZombie();
                newZombie.position = Offset(
                  dumpster.position.dx + _random.nextInt(64) - 32,
                  dumpster.position.dy + _random.nextInt(64) - 32,
                );
                newZombiesPending.add(newZombie);
                logMessages.add('Ein neuer Dough Zombie erscheint aus den Überresten von ${cook.name}!');
              }

              // 25% Chance: Zombie wird zu einem Dough Dumpster
              if (_random.nextInt(100) < 25) {
                final newDumpster = ObjectDoughDumpster();
                logMessages.add('Ein neuer Dough Dumpster erscheint!');
                // Neuen Dumpster in der Nähe des aktuellen positionieren
                newDumpster.position = Offset(
                  dumpster.position.dx + _random.nextInt(64) - 32,
                  dumpster.position.dy + _random.nextInt(64) - 32,
                );
                newDumpsters.add(newDumpster);
              }
            }
          }
        }
      }

      // Ausstehende neue Zombies nach der Iteration hinzufügen
      dumpster.zombieList.addAll(newZombiesPending);

      // Tote Zombies entfernen
      for (final zombie in zombiesToRemove) {
        dumpster.removeZombie(zombie);
      }
    }

    // Ausstehende neue Dumpster nach der Iteration hinzufügen
    doughDumpsterList.addAll(newDumpsters);

    return logMessages;
  }

  /// Baut eine Menge aller aktuell belegten Hex-Felder des Hosts auf.
  /// Wird verwendet, um Kollisionen beim Spawning und Bewegen zu vermeiden.
  /// Optional können Spieler-Einheiten übergeben werden, deren Hex-Felder
  /// dann ebenfalls als belegt gelten (verhindert, dass Zombies auf
  /// Spieler-Token laufen/stapeln).
  Set<int> _buildOccupiedHostHexes({List<ObjectApprentice>? playerUnits}) {
    final occupied = <int>{};
    for (final dumpster in doughDumpsterList) {
      final dh = _pixelToHex(dumpster.position);
      // Kartenbreite ist unbekannt, verwende 100 als konservative Schätzung
      occupied.add(dh.y * 100 + dh.x);
      for (final zombie in dumpster.zombieList) {
        if (zombie.woundValue <= 0) continue;
        final zh = _pixelToHex(zombie.position);
        occupied.add(zh.y * 100 + zh.x);
      }
    }
    // Auch Spieler-Einheiten als belegt markieren,
    // damit Zombies nicht auf ihnen stacken
    if (playerUnits != null) {
      for (final unit in playerUnits) {
        if (unit.woundValue <= 0) continue;
        final uh = _pixelToHex(unit.position);
        occupied.add(uh.y * 100 + uh.x);
      }
    }
    return occupied;
  }

  /// Findet ein freies Hex-Feld in der Nähe eines Ausgangs-Hex.
  /// Durchsucht spiralförmig beginnend beim Start-Hex, bis ein freies Feld
  /// gefunden wird oder der maximale Radius erreicht ist.
  /// Gibt das erste freie Hex als Pixel-Position zurück.
  Offset _findFreeHexNear({
    required int startX,
    required int startY,
    required Set<int> occupied,
    int maxRadius = 12,
  }) {
    // Prüfe, ob das Start-Hex selbst frei ist
    if (!occupied.contains(startY * 100 + startX)) {
      return _hexToPixel(x: startX, y: startY);
    }

    // Spiralförmige Suche
    for (int radius = 1; radius <= maxRadius; radius++) {
      // Obere Kante
      for (int dx = -radius; dx <= radius; dx++) {
        final x = startX + dx;
        final y = startY - radius;
        if (x >= 0 && y >= 0 && !occupied.contains(y * 100 + x)) {
          return _hexToPixel(x: x, y: y);
        }
      }
      // Untere Kante
      for (int dx = -radius; dx <= radius; dx++) {
        final x = startX + dx;
        final y = startY + radius;
        if (x >= 0 && y >= 0 && !occupied.contains(y * 100 + x)) {
          return _hexToPixel(x: x, y: y);
        }
      }
      // Linke Kante (ohne Ecken)
      for (int dy = -radius + 1; dy <= radius - 1; dy++) {
        final x = startX - radius;
        final y = startY + dy;
        if (x >= 0 && y >= 0 && !occupied.contains(y * 100 + x)) {
          return _hexToPixel(x: x, y: y);
        }
      }
      // Rechte Kante (ohne Ecken)
      for (int dy = -radius + 1; dy <= radius - 1; dy++) {
        final x = startX + radius;
        final y = startY + dy;
        if (x >= 0 && y >= 0 && !occupied.contains(y * 100 + x)) {
          return _hexToPixel(x: x, y: y);
        }
      }
    }

    // Fallback: Start-Position zurückgeben
    return _hexToPixel(x: startX, y: startY);
  }

  /// Lässt alle Dough Dumpster neue Zombies spawnen (für jede neue Runde).
  /// Gibt Log-Nachrichten zurück.
  ///
  /// [playerUnits] werden als belegte Hex-Felder markiert, damit Zombies
  /// nicht auf Spieler-Tokens spawnen (Kollisionsvermeidung).
  List<String> performAllDumpsterSpawning({List<ObjectApprentice>? playerUnits}) {
    final logMessages = <String>[];
    // Über eine Kopie iterieren, da während des Spawnens keine neuen
    // Dumpster zur Liste hinzugefügt werden sollen (ConcurrentModification vermeiden)
    for (final dumpster in doughDumpsterList.toList()) {
      final newZombies = dumpster.spawnZombies();
      if (newZombies.isNotEmpty) {
        logMessages.add('${dumpster.name} spawniert ${newZombies.length} neue Zombies!');
        
        // Alle aktuell belegten Hex-Felder ermitteln, inkl. der bereits
        // in diesem Spawning-Durchgang platzierten Zombies
        // Wichtig: playerUnits übergeben, damit Zombies nicht auf Spieler-Tokens spawnen
        final occupied = _buildOccupiedHostHexes(playerUnits: playerUnits);
        final dumpsterHex = _pixelToHex(dumpster.position);

        // Zombies spiralförmig um den Dumpster herum auf freien Feldern platzieren
        for (int i = 0; i < newZombies.length; i++) {
          final freePosition = _findFreeHexNear(
            startX: dumpsterHex.x,
            startY: dumpsterHex.y,
            occupied: occupied,
          );
          newZombies[i].position = freePosition;
          // Neu platzierten Zombie als belegt markieren, damit nachfolgende
          // Zombies in derselben Runde nicht auf demselben Feld spawnen
          final zh = _pixelToHex(freePosition);
          occupied.add(zh.y * 100 + zh.x);
        }
      }
    }
    return logMessages;
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
