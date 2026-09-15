import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/personality.dart';
import 'package:tiled_warfare/services/economy_balance.dart';

/// Tests des Persönlichkeitsmodells (V9).
///
/// Grundlage: `doc/todo/feat_better_restaurant_management/9_Personal.md`
/// (§ 4 Traits, § 4.1 Varianz).
void main() {
  test('es gibt zwölf eindeutige Enneagramm-Profile', () {
    expect(EnneagramProfile.all.length, 12);
    expect(EnneagramProfile.all.map((p) => p.name).toSet().length, 12);
    expect(EnneagramProfile.all.map((p) => p.id).toSet().length, 12);
  });

  test('byName/normalizeId sind tolerant (V6)', () {
    expect(EnneagramProfile.byName('Der Chaot').id, 11);
    expect(EnneagramProfile.byName('Gibt es nicht').id, 0);
    expect(EnneagramProfile.byName(null).id, 0);
    expect(EnneagramProfile.normalizeId(-1), 0);
    expect(EnneagramProfile.normalizeId(99), 0);
    expect(EnneagramProfile.normalizeId(5), 5);
  });

  test('Traits sind deterministisch je (Profil, Charakter-ID)', () {
    for (var profile = 0; profile < EnneagramProfile.all.length; profile++) {
      for (final charId in [0, 1, 4711, 999999]) {
        final a = PersonalityTraits.forProfile(profile, charId);
        final b = PersonalityTraits.forProfile(profile, charId);
        expect(a.vitality, b.vitality);
        expect(a.morale, b.morale);
        expect(a.aggressiveness, b.aggressiveness);
        expect(a.riskTolerance, b.riskTolerance);
        expect(a.tacticalComplexity, b.tacticalComplexity);
        expect(a.helpfulness, b.helpfulness);
        expect(a.thriftiness, b.thriftiness);
        expect(a.shadiness, b.shadiness);
      }
    }
  });

  test('Werte liegen in 0–100 und variieren je Charakter (±1W20)', () {
    for (var profile = 0; profile < EnneagramProfile.all.length; profile++) {
      final vitalities = <int>[];
      for (var charId = 1; charId <= 60; charId++) {
        final t = PersonalityTraits.forProfile(profile, charId);
        final values = [
          t.aggressiveness,
          t.riskTolerance,
          t.tacticalComplexity,
          t.helpfulness,
          t.thriftiness,
          t.vitality,
          t.morale,
          t.shadiness,
        ];
        for (final v in values) {
          expect(
            v,
            inInclusiveRange(
              EconomyBalance.personalityTraitMin,
              EconomyBalance.personalityTraitMax,
            ),
          );
        }
        vitalities.add(t.vitality);
      }
      expect(
        vitalities.toSet().length,
        greaterThan(1),
        reason: 'Profil $profile muss individuelle Werte erzeugen',
      );
      expect(
        vitalities.reduce(max) - vitalities.reduce(min),
        lessThanOrEqualTo(2 * EconomyBalance.personalityVarianceRange),
      );
    }
  });

  test('das Enneagramm-Profil beeinflusst die Traits', () {
    final across = [
      for (var p = 0; p < EnneagramProfile.all.length; p++)
        PersonalityTraits.forProfile(p, 7).vitality,
    ];
    expect(across.toSet().length, greaterThan(1));
  });

  test('forPersonality entspricht forProfile(profile.id, charId)', () {
    const charId = 12345;
    for (final profile in EnneagramProfile.all) {
      final a = PersonalityTraits.forPersonality(profile, charId);
      final b = PersonalityTraits.forProfile(profile.id, charId);
      expect(a.vitality, b.vitality);
      expect(a.morale, b.morale);
    }
  });

  test('ungültige Profil-IDs fallen defensiv auf Profil 0 zurück', () {
    final a = PersonalityTraits.forProfile(-1, 5);
    final b = PersonalityTraits.forProfile(0, 5);
    expect(a.vitality, b.vitality);
    expect(a.morale, b.morale);
  });
}