import 'package:random_name_generator/random_name_generator.dart';
import 'package:tiled_warfare/objects/object_token.dart';
import 'package:tiled_warfare/services/economy_balance.dart';

class ObjectDoughZombie extends ObjectToken {
  ObjectDoughZombie() : super(
    name: "${RandomNames(Zone.us).fullName()} (Dough Zombie)",
    imagePath: "assets/images/token/token_dough_monster_basic.png",
    attackValue: EconomyBalance.doughZombieStats.attack,
    defenseValue: EconomyBalance.doughZombieStats.defense,
    movementValue: EconomyBalance.doughZombieStats.movement,
    damageValue: EconomyBalance.doughZombieStats.damage,
    rangeValue: EconomyBalance.doughZombieStats.range,
    moneyValue: EconomyBalance.doughZombieStats.money,
    xpValue: EconomyBalance.doughZombieStats.xp,
  );
}