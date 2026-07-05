
import 'package:random_name_generator/random_name_generator.dart';
import 'package:tiled_warfare/objects/object_token.dart';

enum CharacterStatus {ready, reeling, hurt, afraid, injured, dying, dead, overkilled}

class ObjectApprentice extends ObjectToken {
  int levelValue = 1;
  int currentXPValue = 0;

  ObjectApprentice({
    String? name,
    String? imagePath,
    super.attackValue = 40,
    super.defenseValue = 20,
    super.movementValue = 6,
    super.damageValue = 2,
    super.rangeValue = 3,
    super.moneyValue = 100,
    super.xpValue = 25,
  }) : super(
    name: name ?? "Apprentice: ${RandomNames(Zone.italy).name()}",
    imagePath: imagePath ?? "assets/images/token/token_cook_basic.png",
  );

  bool earnXP(int xp) {
    currentXPValue = (currentXPValue + xp) % (levelValue * 1000);
    if (currentXPValue == 0) {
      levelValue += 1;
      return true;
    }
    return false;
  }
}
