import 'package:random_name_generator/random_name_generator.dart';
import 'package:tiled_warfare/models/cuisine.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/models/stations.dart';
import 'package:tiled_warfare/objects/player_objects/object_chef_de_partie.dart';
import 'package:tiled_warfare/services/economy_balance.dart';

/// **Pâtissier** – Postenchef der Support-Station `kStationPatissier`
/// (Karrierepfade, V10 § 2).
///
/// Anders als die übrigen Stationen ist der Pâtissier **Support**: er trägt
/// keine Kampf-Aura, sondern verstärkt den Wochen-Refill des gesamten
/// Personals (`EconomyBalance.patissierRefillBonusPercent`). Sein Klassenprofil
/// unterscheidet sich daher bewusst von [ObjectChefDePartie] (eigene Werte aus
/// [EconomyBalance.patissierStats]: schwächer im Angriff, standfester und mit
/// höherem `money`-Wert, der über die Ø-Kapazität wirkt).
///
/// Wie alle Gefechtsklassen erbt er die Attribut- und Persönlichkeitsstruktur
/// des `ObjectApprentice` (kein Parallelmodell). Der Rang bleibt
/// `chef_de_partie`; die Zugehörigkeit zum Klassenprofil ergibt sich
/// deterministisch aus der **persistierten Station** (`StaffData.station`) –
/// es braucht kein neues Schema-Feld.
class ObjectPatissier extends ObjectChefDePartie {
  ObjectPatissier({
    Zone? nameZone,
    Cuisine? cuisine,
    String? imagePath,
    String? name,
  }) : super(
          name: name ??
              'Pâtissier: '
                  '${RandomNames(nameZone ?? cuisine?.zone ?? Zone.italy).fullName()}',
          imagePath: imagePath ?? cuisine?.tokenImagePath,
        ) {
    rank = kRankChefDePartie;
    station = kStationPatissier;
    attackValue = EconomyBalance.patissierStats.attack;
    defenseValue = EconomyBalance.patissierStats.defense;
    movementValue = EconomyBalance.patissierStats.movement;
    damageValue = EconomyBalance.patissierStats.damage;
    rangeValue = EconomyBalance.patissierStats.range;
    moneyValue = EconomyBalance.patissierStats.money;
    xpValue = EconomyBalance.patissierStats.xp;
  }
}
