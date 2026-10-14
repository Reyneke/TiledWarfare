import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/models/stations.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/objects/player_objects/object_chef_de_partie.dart';
import 'package:tiled_warfare/objects/player_objects/object_patissier.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/economy_service.dart';

/// Klassen-Profil des **Pâtissier** (Karrierepfade, V10 § 2; P5): eigene Werte
/// als Support-Station und deterministische Auswahl beim Laden über die
/// persistierte Station.
void main() {
  final base = DateTime.utc(2026, 1, 1);

  ProfileData profileWith({String? station, String rank = kRankChefDePartie}) =>
      ProfileData(
        id: 1,
        name: 'Tester',
        creationDate: base,
        restaurants: [
          RestaurantData(
            id: 10,
            name: 'A',
            district: 'Midtown',
            lastSeenAt: base,
            weekAnchorAt: base,
            staff: [
              StaffData(
                name: 'Chef de partie: Test',
                imagePath: 'x.png',
                type: 'apprentice',
                rank: rank,
                station: station,
                id: 4711,
                personalityId: 2,
                levelValue: 6,
              ),
            ],
          ),
        ],
      );

  test('Klassenprofil: Rang Chef de partie, Station Pâtissier, eigene Werte',
      () {
    final patissier = ObjectPatissier(name: 'Pâtissier: Test', imagePath: 'x.png');

    expect(patissier.rank, kRankChefDePartie);
    expect(patissier.station, kStationPatissier);
    expect(patissier.attackValue, EconomyBalance.patissierStats.attack);
    expect(patissier.defenseValue, EconomyBalance.patissierStats.defense);
    expect(patissier.movementValue, EconomyBalance.patissierStats.movement);
    expect(patissier.damageValue, EconomyBalance.patissierStats.damage);
    expect(patissier.rangeValue, EconomyBalance.patissierStats.range);
    expect(patissier.moneyValue, EconomyBalance.patissierStats.money);
    expect(patissier.xpValue, EconomyBalance.patissierStats.xp);
  });

  test('Pâtissier ist Support-Station: keine Kampf-Aura', () {
    expect(EconomyService.isSupportStation(kStationPatissier), isTrue);
    expect(
      EconomyService.stationAuraPercent(kStationPatissier, StationStat.attack),
      0,
    );
    expect(
      EconomyService.stationAuraPercent(kStationPatissier, StationStat.damage),
      0,
    );
    // Profilunterschied (Tuning): Support statt Front – weniger Angriff,
    // dafür mehr Kapazitäts-Beitrag über den `money`-Wert.
    expect(
      EconomyBalance.patissierStats.attack,
      lessThan(EconomyBalance.chefDePartieStats.attack),
    );
    expect(
      EconomyBalance.patissierStats.money,
      greaterThan(EconomyBalance.chefDePartieStats.money),
    );
  });

  test('Laden wählt das Pâtissier-Profil über die persistierte Station', () {
    final profile = ObjectProfile();
    profile.loadFromData(
      profileWith(station: kStationPatissier),
      restaurantId: 10,
    );

    final loaded = profile.personal.single;
    expect(loaded, isA<ObjectPatissier>());
    expect(loaded.station, kStationPatissier);
    expect(loaded.rank, kRankChefDePartie);
  });

  test('Chef de partie ohne Pâtissier-Station bleibt die Basisklasse', () {
    final profile = ObjectProfile();
    profile.loadFromData(profileWith(), restaurantId: 10);

    final loaded = profile.personal.single;
    expect(loaded, isA<ObjectChefDePartie>());
    expect(loaded, isNot(isA<ObjectPatissier>()));
    expect(loaded.station, isNull);
  });

  test('andere Stationen bleiben die Basisklasse', () {
    final profile = ObjectProfile();
    profile.loadFromData(
      profileWith(station: kStationSaucier),
      restaurantId: 10,
    );

    final loaded = profile.personal.single;
    expect(loaded, isA<ObjectChefDePartie>());
    expect(loaded, isNot(isA<ObjectPatissier>()));
    expect(loaded.station, kStationSaucier);
  });
}
