import 'package:random_name_generator/random_name_generator.dart';
import 'package:tiled_warfare/objects/object_token.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/frt_service.dart';

class ObjectDoughZombie extends ObjectToken {
  /// [strengthFactor] skaliert **alle** Kampfwerte deterministisch aus der
  /// Stadtteil-Korruption zum Spawn-Zeitpunkt (Kapitel 14, Q3). Der Wert kommt
  /// aus [FrtService.monsterStrengthFactor]; `1.0` lässt die Werte unverändert.
  ObjectDoughZombie({double strengthFactor = 1.0})
      : super(
          name: "${RandomNames(Zone.us).fullName()} (Dough Zombie)",
          imagePath: "assets/images/token/token_dough_monster_basic.png",
          attackValue: FrtService.scaleStat(
            EconomyBalance.doughZombieStats.attack,
            strengthFactor,
          ),
          defenseValue: FrtService.scaleStat(
            EconomyBalance.doughZombieStats.defense,
            strengthFactor,
          ),
          movementValue: FrtService.scaleStat(
            EconomyBalance.doughZombieStats.movement,
            strengthFactor,
          ),
          damageValue: FrtService.scaleStat(
            EconomyBalance.doughZombieStats.damage,
            strengthFactor,
          ),
          rangeValue: FrtService.scaleStat(
            EconomyBalance.doughZombieStats.range,
            strengthFactor,
          ),
          moneyValue: FrtService.scaleStat(
            EconomyBalance.doughZombieStats.money,
            strengthFactor,
          ),
          xpValue: FrtService.scaleStat(
            EconomyBalance.doughZombieStats.xp,
            strengthFactor,
          ),
        );
}