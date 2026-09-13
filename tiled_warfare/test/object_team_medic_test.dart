import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/objects/object_host.dart';
import 'package:tiled_warfare/objects/object_team_medic.dart';

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
}
