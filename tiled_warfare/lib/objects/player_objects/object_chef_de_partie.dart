import 'package:random_name_generator/random_name_generator.dart';
import 'package:tiled_warfare/models/cuisine.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/objects/player_objects/object_apprentice.dart';
import 'package:tiled_warfare/services/economy_balance.dart';

/// Postenchef einer Küchenstation (Karrierepfade, V10 – Stufe 3).
///
/// Der `Chef de partie` ist die erste Station der Aufstiegsleiter
/// (`apprentice → line_cook → chef_de_partie`) und erbt – wie alle
/// Gefechtsklassen – die Attribut- und Persönlichkeitsstruktur des
/// [ObjectApprentice] (kein Parallelmodell).
///
/// Ab diesem Rang wählt der Charakter eine [station] (horizontale
/// Spezialisierung, s. `lib/models/stations.dart`), deren Modifikatoren
/// zusätzlich zu den festen Postenchef-Werten wirken.
class ObjectChefDePartie extends ObjectApprentice {
  ObjectChefDePartie({
    Zone? nameZone,
    Cuisine? cuisine,
    String? imagePath,
    String? name,
  }) : super(
          name: name ??
              'Chef de partie: '
                  '${RandomNames(nameZone ?? cuisine?.zone ?? Zone.italy).fullName()}',
          imagePath: imagePath ?? cuisine?.tokenImagePath,
          attackValue: EconomyBalance.chefDePartieStats.attack,
          defenseValue: EconomyBalance.chefDePartieStats.defense,
          movementValue: EconomyBalance.chefDePartieStats.movement,
          damageValue: EconomyBalance.chefDePartieStats.damage,
          rangeValue: EconomyBalance.chefDePartieStats.range,
          moneyValue: EconomyBalance.chefDePartieStats.money,
          xpValue: EconomyBalance.chefDePartieStats.xp,
        ) {
    rank = kRankChefDePartie;
  }
}
