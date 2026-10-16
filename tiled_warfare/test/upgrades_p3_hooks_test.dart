import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/models/restaurant_upgrade.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/rival_service.dart';

/// Wirkungsstellen der ⚙-Erweiterungen aus Paket **P3**
/// (`11b_Restauranterweiterungen.md`): `vault`, `school`, `security`, `stars`.
///
/// Geprüft wird je Baustein genau eine Wirkungsstelle (nie die drei
/// Eingangswerte des passiven Einkommens, § 8):
/// - `security` → `RivalService.incomingDetectionPercent`
/// - `stars` → `RivalService.incomingChancePercent` (und PP, siehe
///   `game_clock_service_test`)
/// - `school` → `ObjectProfile.promotionPurchaseCost` (`promoteToRank`)
/// - `vault` → `ObjectProfile.applyNegativeInterest`
void main() {
  final start = DateTime(2026, 1, 1);

  StaffData crew(int id, {int personalityId = 2}) => StaffData(
    name: 'M$id',
    imagePath: 'x.png',
    type: kRankApprentice,
    rank: kRankApprentice,
    id: id,
    personalityId: personalityId,
    levelValue: 5,
    vitalityCurrent: 50,
    moraleCurrent: 50,
    status: 'ready',
  );

  RestaurantData restaurant({
    Map<UpgradeType, int> upgrades = const {},
    List<StaffData>? staffList,
    int budget = 20000,
  }) => RestaurantData(
    id: 10,
    name: 'A',
    district: 'Midtown',
    budget: budget,
    staff: staffList ?? [crew(1)],
    upgrades: upgrades,
    lastSeenAt: start,
    weekAnchorAt: start,
  );

  ProfileData profileOf(RestaurantData slot) => ProfileData(
    id: 1,
    name: 'Tester',
    creationDate: start,
    restaurants: [slot],
  );

  group('security – Entdeckung eingehender Sabotage (§ 10)', () {
    test('je Stufe 5 Prozentpunkte mehr Entdeckung', () {
      final plain = RivalService.incomingDetectionPercent(restaurant());
      // Kampfpersonal mit Profil ⇒ Ø-shadiness > 0 ⇒ Entdeckung > 0.
      expect(plain, greaterThan(0));
      expect(
        RivalService.incomingDetectionPercent(
          restaurant(upgrades: const {UpgradeType.security: 3}),
        ),
        (plain + 15).clamp(0, 100),
      );
      expect(
        RivalService.incomingDetectionPercent(
          restaurant(upgrades: const {UpgradeType.security: 1}),
        ),
        (plain + 5).clamp(0, 100),
      );
    });

    test('ohne Sicherheitstechnik bleibt die Entdeckung unverändert', () {
      final plain = RivalService.incomingDetectionPercent(restaurant());
      final other = RivalService.incomingDetectionPercent(
        restaurant(upgrades: const {UpgradeType.tables: 5}),
      );
      expect(other, plain);
    });
  });

  group('stars – Sabotage-Ziel-Schutz (§ 10)', () {
    test('je Stufe 5 Prozentpunkte seltener Ziel eines Angriffs', () {
      const attackChance = EconomyBalance.incomingSabotageChanceBasePercent;
      expect(RivalService.incomingChancePercent(restaurant()), attackChance);
      expect(
        RivalService.incomingChancePercent(
          restaurant(upgrades: const {UpgradeType.stars: 1}),
        ),
        attackChance - 5,
      );
      expect(
        RivalService.incomingChancePercent(
          restaurant(upgrades: const {UpgradeType.stars: 5}),
        ),
        (attackChance - 25).clamp(0, 100),
      );
    });

    test('die geminderte Wahrscheinlichkeit wirkt auf die Angreifer', () {
      final plain = restaurant();
      final starred = restaurant(upgrades: const {UpgradeType.stars: 5});
      final relief = RivalService.incomingChancePercent(starred);
      for (var i = 0; i < 60; i++) {
        final anchor = start.add(Duration(days: 7 * i));
        final without = RivalService.incomingAttackerIds(plain, anchor);
        final starredAttackers =
            RivalService.incomingAttackerIds(starred, anchor);
        // Teilmenge und deterministisch – gleiche Würfel, engere Schwelle.
        for (final id in starredAttackers) {
          expect(without.contains(id), isTrue);
          expect(
            RivalService.incomingAttemptOccurs(
              id,
              anchor,
              chancePercent: relief,
            ),
            isTrue,
          );
        }
        expect(starredAttackers.length, lessThanOrEqualTo(without.length));
      }
    });
  });

  group('school – Beförderungskosten (§ 10)', () {
    test('der Schulungsraum senkt Anzeige- und Buchungspreis', () {
      final profile = ObjectProfile();
      profile.loadFromData(
        profileOf(restaurant(upgrades: const {UpgradeType.school: 3})),
        restaurantId: 10,
      );
      // 500 € − 15 % = 425 €.
      expect(profile.promotionPurchaseCost(kRankLineCook), 425);
      final before = profile.budget;
      final promoted = profile.promoteToRank(
        profile.personal.single,
        kRankLineCook,
      );
      expect(promoted, isNotNull);
      expect(profile.budget, before - 425);
    });

    test('ohne Schulungsraum kostet die Beförderung den vollen Preis', () {
      final profile = ObjectProfile();
      profile.loadFromData(profileOf(restaurant()), restaurantId: 10);
      expect(
        profile.promotionPurchaseCost(kRankLineCook),
        EconomyBalance.upgradeToLineCookCost,
      );
      final before = profile.budget;
      expect(
        profile.promoteToRank(profile.personal.single, kRankLineCook),
        isNotNull,
      );
      expect(profile.budget, before - EconomyBalance.upgradeToLineCookCost);
    });
  });

  group('vault – Negativzinsen im Spielstand (§ 10)', () {
    test('der Tresor senkt die Zinsen nach dem Gefecht', () {
      final profile = ObjectProfile();
      profile.loadFromData(
        profileOf(
          restaurant(upgrades: const {UpgradeType.vault: 3}, budget: -1000),
        ),
        restaurantId: 10,
      );
      profile.applyNegativeInterest();
      // 10 % → 7 % (30 % Nachlass): −1000 − 70 = −1070.
      expect(profile.budget, -1070);
    });

    test('ohne Tresor bleiben die vollen 10 %', () {
      final profile = ObjectProfile();
      profile.loadFromData(
        profileOf(restaurant(budget: -1000)),
        restaurantId: 10,
      );
      profile.applyNegativeInterest();
      expect(profile.budget, -1100);
    });
  });
}
