import 'package:random_name_generator/random_name_generator.dart';
import 'package:tiled_warfare/models/cuisine.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/objects/player_objects/object_apprentice.dart';
import 'package:tiled_warfare/services/economy_balance.dart';

/// Stellvertreter des Küchenchefs (Karrierepfade, V10 – Stufe 4).
///
/// Der `Sous-chef` steht zwischen `Chef de partie` und `Chef de cuisine` und
/// erbt – wie alle Gefechtsklassen – die Attribut- und Persönlichkeitsstruktur
/// des [ObjectApprentice]. Seine Stations-Aura wirkt mit größerem Radius
/// (`EconomyBalance.stationAuraRadiusByRank`).
class ObjectSousChef extends ObjectApprentice {
  ObjectSousChef({
    Zone? nameZone,
    Cuisine? cuisine,
    String? imagePath,
    String? name,
  }) : super(
          name: name ??
              'Sous-chef: '
                  '${RandomNames(nameZone ?? cuisine?.zone ?? Zone.italy).fullName()}',
          imagePath: imagePath ?? cuisine?.tokenImagePath,
          attackValue: EconomyBalance.sousChefStats.attack,
          defenseValue: EconomyBalance.sousChefStats.defense,
          movementValue: EconomyBalance.sousChefStats.movement,
          damageValue: EconomyBalance.sousChefStats.damage,
          rangeValue: EconomyBalance.sousChefStats.range,
          moneyValue: EconomyBalance.sousChefStats.money,
          xpValue: EconomyBalance.sousChefStats.xp,
        ) {
    rank = kRankSousChef;
  }
}
