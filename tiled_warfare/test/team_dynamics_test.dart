import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/personality.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/game_clock_service.dart';
import 'package:tiled_warfare/services/team_dynamics_service.dart';

/// Teamdynamik (V9 „Teamdynamik“, P5): deterministische Paar-Affinität und
/// ihre additive Wirkung auf die Eingangswerte des passiven Einkommens.
void main() {
  StaffData koch({required int personalityId, required int id}) => StaffData(
    name: 'Koch $id',
    imagePath: 'x.png',
    type: 'apprentice',
    id: id,
    personalityId: personalityId,
  );

  RestaurantData restaurant(List<StaffData> staff) =>
      RestaurantData(name: 'Test', district: 'Harlem', staff: staff);

  /// Sucht deterministisch ein Zweier-Team **derselben** Persönlichkeit mit der
  /// gewünschten Affinität (`+1`/`−1`) – dadurch bleibt die Hilfsbereitschaft
  /// (die von `personalityId` *und* `id` abhängt) über Teams hinweg vergleichbar.
  List<StaffData> pairWithAffinity(int wanted) {
    for (var idA = 1; idA <= 200; idA++) {
      for (var idB = idA + 1; idB <= 200; idB++) {
        final a = koch(personalityId: 0, id: idA);
        final b = koch(personalityId: 0, id: idB);
        if (TeamDynamicsService.pairAffinity(a, b) == wanted) return [a, b];
      }
    }
    throw StateError('Kein Paar mit Affinität $wanted gefunden');
  }

  double helpfulness(List<StaffData> staff) => staff
          .map((s) => PersonalityTraits.forProfile(s.personalityId, s.id).helpfulness)
          .reduce((a, b) => a + b) /
      staff.length;

  group('Paar-Affinität', () {
    test('ist deterministisch, symmetrisch und im Wertebereich', () {
      final a = koch(personalityId: 3, id: 11);
      final b = koch(personalityId: 7, id: 22);

      expect(
        TeamDynamicsService.pairAffinity(a, b),
        TeamDynamicsService.pairAffinity(b, a),
      );
      expect(
        TeamDynamicsService.pairAffinity(a, b),
        TeamDynamicsService.pairAffinity(a, b),
      );
      expect(TeamDynamicsService.pairAffinity(a, b), inInclusiveRange(-1, 1));
    });

    test('Team ohne Profil (Alt-Daten) bleibt neutral', () {
      final legacy = StaffData(
        name: 'Alt',
        imagePath: 'x.png',
        type: 'apprentice',
        id: 5,
      );

      expect(
        TeamDynamicsService.pairAffinity(legacy, koch(personalityId: 2, id: 9)),
        0,
      );
      expect(TeamDynamicsService.averageAffinity([legacy, legacy]), 0.0);
    });

    test('weniger als zwei Charaktere ⇒ keine Chemie', () {
      expect(TeamDynamicsService.averageAffinity(const []), 0.0);
      expect(
        TeamDynamicsService.averageAffinity([koch(personalityId: 1, id: 1)]),
        0.0,
      );
      expect(
        TeamDynamicsService.averageAffinity([koch(personalityId: 1, id: 1)]),
        isNot(isNaN),
      );
    });

    test('Ø-Affinität bleibt in der Domäne −1 … +1', () {
      final team = [
        for (var i = 1; i <= 8; i++) koch(personalityId: i % 12, id: i * 37),
      ];
      expect(
        TeamDynamicsService.averageAffinity(team),
        inInclusiveRange(-1.0, 1.0),
      );
    });

    test('Bonus-Funktionen skalieren die Ø-Affinität mit dem Gewicht', () {
      final friendly = pairWithAffinity(1);
      final tense = pairWithAffinity(-1);

      expect(
        TeamDynamicsService.attractivenessBonus(friendly),
        closeTo(EconomyBalance.teamChemistryAttractivenessWeight, 1e-9),
      );
      expect(
        TeamDynamicsService.attractivenessBonus(tense),
        closeTo(-EconomyBalance.teamChemistryAttractivenessWeight, 1e-9),
      );
      expect(
        TeamDynamicsService.satisfactionBonus(friendly),
        closeTo(EconomyBalance.teamChemistrySatisfactionWeight, 1e-9),
      );
      expect(
        TeamDynamicsService.satisfactionBonus(tense),
        closeTo(-EconomyBalance.teamChemistrySatisfactionWeight, 1e-9),
      );
    });
  });

  group('Wirkung auf die Eingangswerte', () {
    test('Sympathie hebt die Zufriedenheit, Spannung senkt sie', () {
      final friendly = GameClockService.satisfactionOf(
        restaurant(pairWithAffinity(1)),
      );
      final tense = GameClockService.satisfactionOf(
        restaurant(pairWithAffinity(-1)),
      );

      expect(friendly, greaterThan(tense));
      // Beide Teams sind gesund und ohne Ergebnis – der Unterschied ist
      // ausschließlich die Team-Chemie (+1 … −1).
      expect(
        friendly - tense,
        closeTo(2 * EconomyBalance.teamChemistrySatisfactionWeight, 1e-9),
      );
    });

    test('Sympathie hebt die Attraktivität – additiv neben der Hilfsbereitschaft',
        () {
      final friendlyTeam = pairWithAffinity(1);
      final tenseTeam = pairWithAffinity(-1);

      final expected =
          EconomyBalance.personalityAttractivenessWeight *
              (helpfulness(friendlyTeam) - helpfulness(tenseTeam)) +
          2 * EconomyBalance.teamChemistryAttractivenessWeight;
      final actual =
          GameClockService.attractivenessOf(restaurant(friendlyTeam)) -
          GameClockService.attractivenessOf(restaurant(tenseTeam));

      expect(actual, closeTo(expected, 1e-9));
    });

    test('Team-Chemie bleibt innerhalb der Eingangs-Domäne', () {
      final extremes = [
        for (var i = 1; i <= 6; i++) koch(personalityId: i, id: i),
      ];
      final team = restaurant(extremes);

      expect(
        GameClockService.attractivenessOf(team),
        inInclusiveRange(0.0, EconomyBalance.inputDomainMax),
      );
      expect(
        GameClockService.satisfactionOf(team),
        inInclusiveRange(0.0, EconomyBalance.inputDomainMax),
      );
    });
  });
}
