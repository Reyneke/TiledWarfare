
import 'package:random_name_generator/random_name_generator.dart';
import 'package:tiled_warfare/models/cuisine.dart';
import 'package:tiled_warfare/objects/player_objects/object_apprentice.dart';

class ObjectLineCook extends ObjectApprentice {
  ObjectLineCook({Zone? nameZone, Cuisine? cuisine, String? imagePath}) : super(
    name: "Line Cook: ${RandomNames(nameZone ?? cuisine?.zone ?? Zone.italy).fullName()}",
    imagePath: imagePath ?? cuisine?.tokenImagePath,
    attackValue: 80,
    defenseValue: 40,
    movementValue: 3,
    damageValue: 2,
    rangeValue: 3,
    moneyValue: 1000,
    xpValue: 100
  );
}
