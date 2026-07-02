import 'dart:math';

import 'package:tiled_warfare/objects/object_dough_zombie.dart';
import 'package:tiled_warfare/objects/object_token.dart';

class ObjectDoughDumpster extends ObjectToken {
  ObjectDoughDumpster() : super(
    name: "Dough Dumpster",
    imagePath: "assets/images/token/token_spawner.png",
    woundValue: 50,
    attackValue: 0,
    defenseValue: 0,
    movementValue: 0,
    damageValue: 0,
    rangeValue: 0,
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
