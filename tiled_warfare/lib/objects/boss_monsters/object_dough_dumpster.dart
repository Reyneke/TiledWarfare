import 'dart:math';

import 'package:tiled_warfare/objects/monsters/object_dough_zombie.dart';
import 'package:tiled_warfare/objects/object_token.dart';

/// Zählt, wie viele Dough Dumpster-Instanzen bereits erstellt wurden.
/// Der erste heißt "Donald Trumpster", alle weiteren erhalten
/// amerikanische Vornamen + "Trumpster" als Nachnamen.
int _dumpsterInstanceCounter = 0;

/// Generiert einen Namen für den Dough Dumpster.
String _generateTrumpsterName() {
  _dumpsterInstanceCounter++;
  if (_dumpsterInstanceCounter <= 1) {
    return "Donald Trumpster";
  }
  final random = Random();
  // Liste amerikanischer Vornamen für zusätzliche Instanzen
  final firstNames = [
    'John', 'Michael', 'David', 'James', 'Robert', 'William', 'Richard',
    'Joseph', 'Thomas', 'Christopher', 'Daniel', 'Matthew', 'Anthony',
    'Mark', 'Steven', 'Andrew', 'Kenneth', 'George', 'Edward', 'Brian',
    'Kevin', 'Jason', 'Jeffrey', 'Ryan', 'Jacob', 'Nicholas', 'Eric',
    'Stephen', 'Timothy', 'Larry', 'Scott', 'Frank', 'Brandon', 'Raymond',
    'Gregory', 'Joshua', 'Jerry', 'Dennis', 'Patrick', 'Walter', 'Peter',
    'Harold', 'Douglas', 'Henry', 'Carl', 'Arthur', 'Albert', 'Ralph',
    'Willie', 'Billy', 'Harry', 'Roy', 'Eugene', 'Jack', 'Joe', 'Louis',
    'Roger', 'Earl', 'Sam', 'Ernest', 'Francis', 'Clarence', 'Henry',
    'Charlie', 'Stanley', 'Leonard', 'Nathan', 'Clyde', 'Curtis', 'Allen',
    'Marvin', 'Philip', 'Leslie', 'Clifford', 'Lester', 'Chester',
    'Lloyd', 'Harvey', 'Leroy', 'Emmett', 'Virgil', 'Melvin', 'Alfred',
    'Floyd', 'Dale', 'Gene', 'Evan', 'Milton', 'Devin', 'Russell',
    'Sammy', 'Glen', 'Oscar', 'Perry', 'Karl', 'Freddie', 'Lewis',
    'Gordon', 'Eddie', 'Jay', 'Jessie', 'Darrell', 'Ronnie', 'Wendell',
    'Lauren', 'Morgan', 'Taylor', 'Jordan', 'Casey', 'Dakota', 'Skyler',
  ];
  final firstName = firstNames[random.nextInt(firstNames.length)];
  return '$firstName Trumpster';
}

class ObjectDoughDumpster extends ObjectToken {
  ObjectDoughDumpster() : super(
    name: _generateTrumpsterName(),
    imagePath: "assets/images/token/token_spawner.png",
    woundValue: 50,
    attackValue: 0,
    defenseValue: 0,
    movementValue: 0,
    damageValue: 0,
    rangeValue: 0,
    moneyValue: 1000,
    xpValue: 1000,
  );

  List<ObjectDoughZombie> zombieList = [];

  /// Spawnt 1w6 (1-6) Dough Zombies und fügt sie der zombieList hinzu.
  /// Gibt die Liste der neu erschaffenen Zombies zurück.
  List<ObjectDoughZombie> spawnZombies() {
    final random = Random();
    final count = random.nextInt(6) + 1; // 1w6: 1 bis 6
    final List<ObjectDoughZombie> newZombies = [];

    for (int i = 0; i < count; i++) {
      final zombie = ObjectDoughZombie();
      zombieList.add(zombie);
      newZombies.add(zombie);
    }

    return newZombies;
  }

  /// Entfernt einen Zombie aus der zombieList (z. B. wenn er zerstört wurde).
  void removeZombie(ObjectDoughZombie zombie) {
    zombieList.remove(zombie);
  }

  /// Gibt die Anzahl der aktuell kontrollierten Zombies zurück.
  int get zombieCount => zombieList.length;
}