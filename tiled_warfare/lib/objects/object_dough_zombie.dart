import 'package:tiled_warfare/objects/object_token.dart';

class ObjectDoughZombie extends ObjectToken {
  ObjectDoughZombie() : super(
    name: "Dough Zombie",
    imagePath: "assets/images/token/token_dough_monster_basic.png"
  );
}

/*
Dough Zombies sind vom Dough Monster konvertierte Personen. Sie sind dem Dough ergeben und folgen seinem Willen.
Stirbt ein Dough Zombie, besteht eine Chance von 20%, dass er ein Objekt vom Typ "Dough Dumpster" erzeugt.
Tötet ein Dough Zombie einen Line Cook, besteht eine Chance von 25%, dass der Line Cook selbst zu einem Dough Zombie konvertiert wird.
Ihr Angriffmuster ist simpel: Sie bewegen sich auf den nächsten Line Cook zu und greifen ihn an, wenn sie in Reichweite sind.

Sie haben die folgenden Eigenschaften:
attackValue = 40;
defenseValue = 40;
movementValue = 1;
damageValue = 1;
rangeValue = 0;
 */