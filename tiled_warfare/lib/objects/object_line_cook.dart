
import 'package:random_name_generator/random_name_generator.dart';
import 'package:tiled_warfare/objects/object_token.dart';

class ObjectLineCook extends ObjectToken {
  ObjectLineCook() : super(
    name: "Line Cook: ${RandomNames(Zone.italy).fullName()}",
    imagePath: "assets/images/token/token_cook_basic.png",
    attackValue: 40,
    defenseValue: 40,
    movementValue: 3,
    damageValue: 2,
    rangeValue: 3,
  );
}
