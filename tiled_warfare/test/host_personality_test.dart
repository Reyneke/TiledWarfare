import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/personality.dart';
import 'package:tiled_warfare/objects/object_host.dart';

/// Host-Fuzzy-Persönlichkeit (V9 § 5, Phase 6):
/// Die Regelbasis wird nun tatsächlich gehalten und ausgewertet.
void main() {
  test('die Regelbasis bleibt erhalten und ist befüllt', () {
    for (final profile in EnneagramProfile.all) {
      final personality = HostPersonality(profile);
      expect(
        personality.ruleBase.rules,
        isNotEmpty,
        reason: 'Profil ${profile.name} muss Regeln haben',
      );
    }
  });

  test('evaluate liefert Bias-Werte in 0–100 und ist deterministisch', () {
    final personality = HostPersonality(EnneagramProfile.all[7]);
    personality.evaluate(threatLevel: 80, ownStrength: 20, tacticalSprawl: 60);
    final aggression = personality.aggressionBias;
    final risk = personality.riskToleranceBias;
    final tactical = personality.tacticalBias;
    expect(aggression, inInclusiveRange(0, 100));
    expect(risk, inInclusiveRange(0, 100));
    expect(tactical, inInclusiveRange(0, 100));

    personality.evaluate(threatLevel: 80, ownStrength: 20, tacticalSprawl: 60);
    expect(personality.aggressionBias, aggression);
    expect(personality.riskToleranceBias, risk);
    expect(personality.tacticalBias, tactical);
  });

  test('Bias ist vor der ersten Auswertung neutral (50)', () {
    final personality = HostPersonality(EnneagramProfile.all.first);
    expect(personality.aggressionBias, 50);
    expect(personality.riskToleranceBias, 50);
    expect(personality.tacticalBias, 50);
  });

  test('ObjectHost bewertet die Persönlichkeit im Zug (V9)', () {
    final host = ObjectHost();
    host.refreshPersonality(ownUnits: 1, enemyUnits: 3, visibleTargets: 2);
    expect(host.aggressionBias, inInclusiveRange(0, 100));
    expect(host.riskToleranceBias, inInclusiveRange(0, 100));
    expect(host.tacticalBias, inInclusiveRange(0, 100));
    expect(host.rollInitiative(), inInclusiveRange(1, 100));
  });
}