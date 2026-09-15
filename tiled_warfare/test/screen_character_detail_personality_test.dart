import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/l10n/app_localizations.dart';
import 'package:tiled_warfare/objects/player_objects/object_apprentice.dart';
import 'package:tiled_warfare/screens/screen_character_detail.dart';

/// Detailansicht: Persönlichkeit, Ressourcen und Erschöpfungs-Malus (V9, Phase 7).
void main() {
  testWidgets('zeigt Persönlichkeit, Ressourcen, Override und Malus',
      (tester) async {
    final now = DateTime.now();
    final character = ObjectApprentice(
      name: 'Testkoch',
      imagePath: 'x.png',
      personalityId: 2,
      id: 4711,
      vitalityCurrent: 12,
      moraleCurrent: 40,
      personalityOverrideId: 5,
      personalityOverrideCause: 'stress',
      personalityOverrideUntil: now.add(const Duration(hours: 4)),
      vitalityZeroSinceAt: now.subtract(const Duration(days: 2)),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScreenCharacterDetail(character: character),
      ),
    );

    expect(find.textContaining('Persönlichkeit'), findsOneWidget);
    expect(find.textContaining('Vitalität 12/100'), findsOneWidget);
    expect(find.textContaining('Unter Stress'), findsOneWidget);
    expect(find.textContaining('Erschöpft'), findsOneWidget);
  });
}