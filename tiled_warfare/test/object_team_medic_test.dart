import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/medic_quality.dart';
import 'package:tiled_warfare/models/personality.dart';
import 'package:tiled_warfare/objects/object_team_medic.dart';
import 'package:tiled_warfare/services/economy_service.dart';

/// Tests der Teamarzt-Bewertung nach dem Entfernen der Fuzzy-Engine (V5,
/// `doc/todo/feat_better_restaurant_management/5_Halbfertige_Features.md`).
void main() {
  test('Hilfsbereitschaft liegt überall in 0–100', () {
    for (final profile in EnneagramProfile.all) {
      for (final quality in MedicQuality.values) {
        final score = ObjectTeamMedic.helpfulnessScoreFor(profile, quality);
        expect(
          score,
          inInclusiveRange(0, 100),
          reason: '${profile.name} / ${quality.name}',
        );
      }
    }
  });

  test('Behandlungsqualität liegt überall in 0–100', () {
    for (final profile in EnneagramProfile.all) {
      for (final quality in MedicQuality.values) {
        final score =
            ObjectTeamMedic.treatmentQualityScoreFor(profile, quality);
        expect(
          score,
          inInclusiveRange(0, 100),
          reason: '${profile.name} / ${quality.name}',
        );
      }
    }
  });

  test('Regressionsschutz: Bestwert wird auf 100 begrenzt (vorher > 100)', () {
    final highest = EnneagramProfile.all
        .map((p) => ObjectTeamMedic.helpfulnessScoreFor(p, MedicQuality.hoch))
        .reduce((a, b) => a > b ? a : b);

    // Ohne Clamp hätte 50 + 96 + 30 = 176 entstehen können.
    expect(highest, 100);
  });

  test('injizierter Zufall/Zeit macht den Arzt deterministisch (V7/L7)', () {
    final now = DateTime(2026, 1, 1);
    final a = ObjectTeamMedic(random: Random(7), now: () => now);
    final b = ObjectTeamMedic(random: Random(7), now: () => now);

    expect(a.quality, b.quality);
    expect(a.enneagramProfile, b.enneagramProfile);
    // V9: Der Lohn hängt zusätzlich an der Thriftiness des Individuums
    // (Charakter-ID aus Name + Zeit) – gleiche Basis, eigene Ausprägung.
    expect(
      a.costPerWeek,
      EconomyService.weeklyMedicCost(
        a.quality,
        0,
        PersonalityTraits.forProfile(a.enneagramProfile.id, a.id).thriftiness,
      ),
    );
  });
}
