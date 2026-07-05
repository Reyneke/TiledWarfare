
import 'package:random_name_generator/random_name_generator.dart';
import 'package:tiled_warfare/objects/player_objects/object_appretice.dart';

class ObjectLineCook extends ObjectApprentice {
  ObjectLineCook() : super(
    name: "Line Cook: ${RandomNames(Zone.italy).fullName()}",
    imagePath: "assets/images/token/token_cook_basic.png",
    attackValue: 80,
    defenseValue: 40,
    movementValue: 3,
    damageValue: 2,
    rangeValue: 3,
    moneyValue: 1000,
    xpValue: 100
  );
}
