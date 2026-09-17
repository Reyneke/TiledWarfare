import 'package:random_name_generator/random_name_generator.dart';
import 'package:tiled_warfare/models/cuisine.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/objects/player_objects/object_apprentice.dart';
import 'package:tiled_warfare/services/economy_balance.dart';

/// Küchenchef (Karrierepfade, V10 – Stufe 5, Doppelrolle).
///
/// Der `Chef de cuisine` ist die Spitze der Aufstiegsleiter und trägt eine
/// **Doppelrolle**:
/// - **aktiv** (zugeteilt, [kHeadChefRoleActive]): Management-Profil – er bufft
///   die drei Werte des passiven Einkommens und zieht nicht ins Gefecht.
/// - **formell** (nicht zugeteilt, [kHeadChefRoleFormal]): kämpfende Einheit mit
///   den Stat-Boni der Aufstiegsleiter und Stations-Aura; rückt automatisch
///   nach, sobald der aktive Chef ausfällt.
///
/// Pro Restaurant ist höchstens **ein aktiver** Chef möglich (Unikat-Invariante,
/// `ObjectProfile.assignHeadChef`); formelle Titelträger sind unbegrenzt.
class ObjectHeadChef extends ObjectApprentice {
  ObjectHeadChef({
    Zone? nameZone,
    Cuisine? cuisine,
    String? imagePath,
    String? name,
  }) : super(
          name: name ??
              'Chef de cuisine: '
                  '${RandomNames(nameZone ?? cuisine?.zone ?? Zone.italy).fullName()}',
          imagePath: imagePath ?? cuisine?.tokenImagePath,
          attackValue: EconomyBalance.headChefFormalStats.attack,
          defenseValue: EconomyBalance.headChefFormalStats.defense,
          movementValue: EconomyBalance.headChefFormalStats.movement,
          damageValue: EconomyBalance.headChefFormalStats.damage,
          rangeValue: EconomyBalance.headChefFormalStats.range,
          moneyValue: EconomyBalance.headChefFormalStats.money,
          xpValue: EconomyBalance.headChefFormalStats.xp,
        ) {
    rank = kRankHeadChef;
  }
}
