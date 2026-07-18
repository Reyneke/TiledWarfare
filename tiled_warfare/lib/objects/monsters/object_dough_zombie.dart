import 'package:random_name_generator/random_name_generator.dart';
import 'package:tiled_warfare/objects/object_token.dart';

class ObjectDoughZombie extends ObjectToken {
  ObjectDoughZombie() : super(
    name: "${RandomNames(Zone.us).fullName()} (Dough Zombie)",
    imagePath: "assets/images/token/token_dough_monster_basic.png",
    attackValue: 40,
    defenseValue: 40,
    movementValue: 1,
    damageValue: 1,
    rangeValue: 0,
    moneyValue: 100,
    xpValue: 25,
  );
}