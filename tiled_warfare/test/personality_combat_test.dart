import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/personality.dart';
import 'package:tiled_warfare/objects/player_objects/object_apprentice.dart';

/// Persönlichkeits-Wirkung im Gefecht (V9 § 5, Phase 5).
void main() {
  const charId = 4242;

  ObjectApprentice apprenticeFor(int profileId, {int overrideId = -1}) =>
      ObjectApprentice(
        name: 'Tester',
        imagePath: 'x.png',
        personalityId: profileId,
        personalityOverrideId: overrideId,
        id: charId,
      );

  test('Extrem-Profile heben/senken Angriff, Verteidigung, Schaden, Bewegung', () {
    // Profile mit der höchsten/niedrigsten Ausprägung für diese Charakter-ID.
    final byAggression = EnneagramProfile.all.toList()
      ..sort((a, b) => PersonalityTraits.forProfile(a.id, charId)
          .aggressiveness
          .compareTo(
              PersonalityTraits.forProfile(b.id, charId).aggressiveness));
    final lowest = byAggression.first;
    final highest = byAggression.last;

    final weak = apprenticeFor(lowest.id);
    final strong = apprenticeFor(highest.id);

    expect(weak.personalityAttackValue, lessThan(weak.attackValue));
    expect(strong.personalityAttackValue, greaterThan(strong.attackValue));
    expect(weak.personalityDefenseValue, lessThan(weak.defenseValue));
    expect(strong.personalityDefenseValue, greaterThan(strong.defenseValue));
  });

  test('das effektive Profil folgt dem Stress-/Ruhe-Override (V9 § 6)', () {
    final base = apprenticeFor(0);
    final overridden = apprenticeFor(0, overrideId: 5);
    final reference = apprenticeFor(5);

    expect(base.effectivePersonality.id, 0);
    expect(overridden.effectivePersonality.id, 5);
    expect(
      overridden.personalityAttackValue,
      reference.personalityAttackValue,
    );
    expect(
      overridden.personalityDefenseValue,
      reference.personalityDefenseValue,
    );
  });

  test('Persönlichkeits-Traits sind über den Charakter abrufbar', () {
    final a = apprenticeFor(3);
    final traits = a.traits;
    expect(
      traits.aggressiveness,
      PersonalityTraits.forProfile(3, charId).aggressiveness,
    );
    expect(a.personalityMovementValue, isPositive);
  });
}