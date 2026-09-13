
import 'package:random_name_generator/random_name_generator.dart';
import 'package:tiled_warfare/models/cuisine.dart';
import 'package:tiled_warfare/objects/player_objects/object_apprentice.dart';
import 'package:tiled_warfare/services/economy_balance.dart';

class ObjectLineCook extends ObjectApprentice {
  ObjectLineCook({
    Zone? nameZone,
    Cuisine? cuisine,
    String? imagePath,
    String? name,
  }) : super(
    name: name ??
        "Line Cook: ${RandomNames(nameZone ?? cuisine?.zone ?? Zone.italy).fullName()}",
    imagePath: imagePath ?? cuisine?.tokenImagePath,
    attackValue: EconomyBalance.lineCookStats.attack,
    defenseValue: EconomyBalance.lineCookStats.defense,
    movementValue: EconomyBalance.lineCookStats.movement,
    damageValue: EconomyBalance.lineCookStats.damage,
    rangeValue: EconomyBalance.lineCookStats.range,
    moneyValue: EconomyBalance.lineCookStats.money,
    xpValue: EconomyBalance.lineCookStats.xp,
  );
}
