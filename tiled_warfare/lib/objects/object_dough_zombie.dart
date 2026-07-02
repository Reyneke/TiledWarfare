import 'package:tiled_warfare/objects/object_token.dart';

class ObjectDoughZombie extends ObjectToken {
  ObjectDoughZombie() : super(
    name: "Dough Zombie",
    imagePath: "assets/images/token/token_dough_monster_basic.png",
    attackValue: 40,
    defenseValue: 40,
    movementValue: 1,
    damageValue: 1,
    rangeValue: 0,
  );
}