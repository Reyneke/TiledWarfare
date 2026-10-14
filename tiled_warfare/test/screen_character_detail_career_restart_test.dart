import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/l10n/app_localizations.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/screens/screen_character_detail.dart';
import 'package:tiled_warfare/services/economy_service.dart';

/// Detailseite: Karriere-Neustart (V10 § 6; P5) – Button, Bestätigungsdialog,
/// Abbruch ohne Wirkung und die tatsächliche Buchung.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final base = DateTime(2026, 1, 1);

  Widget app(Widget home) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('de'),
    home: home,
  );

  StaffData sousChef({int level = 7}) => StaffData(
    name: 'Sous-chef: Testkoch',
    imagePath: 'x.png',
    type: 'apprentice',
    rank: kRankSousChef,
    id: 4711,
    personalityId: 3,
    levelValue: level,
    currentXPValue: 250,
  );

  void loadProfile({int budget = 20000, StaffData? staff}) {
    ObjectProfile().loadFromData(
      ProfileData(
        id: 1,
        name: 'Testprofil',
        creationDate: base,
        restaurants: [
          RestaurantData(
            id: 10,
            name: 'Testrestaurant',
            district: 'Harlem',
            budget: budget,
            lastSeenAt: base,
            weekAnchorAt: base,
            staff: staff == null ? [] : [staff],
          ),
        ],
      ),
      restaurantId: 10,
    );
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final character = ObjectProfile().personal.single;
    await tester.pumpWidget(app(ScreenCharacterDetail(character: character)));
    await tester.pump();
  }

  testWidgets('Lehrlinge sehen keine Neustart-Aktion', (tester) async {
    loadProfile(
      staff: StaffData(
        name: 'Apprentice: Testkoch',
        imagePath: 'x.png',
        type: 'apprentice',
        id: 7,
        personalityId: 1,
      ),
    );
    await pumpScreen(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Karriere-Neustart'), findsNothing);
  });

  testWidgets(
    'Karriere-Neustart: Dialog, Abbruch ohne Wirkung, Bestätigung bucht (P5)',
    (tester) async {
      loadProfile(staff: sousChef());
      final cost = EconomyService.careerRestartCost(level: 7);
      await pumpScreen(tester);

      // Sichtbar mit Kosten.
      expect(find.text('Karriere-Neustart'), findsOneWidget);
      expect(find.textContaining('$cost'), findsWidgets);

      // Dialog öffnen.
      await tester.tap(find.text('Neu starten'));
      await tester.pumpAndSettle();
      expect(find.textContaining('nicht erstattet'), findsOneWidget);

      // Abbruch: keine Buchung, kein Reset.
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(ObjectProfile().budget, 20000);
      expect(ObjectProfile().personal.single.rank, kRankSousChef);

      // Bestätigen: Buchung und Rückstufung zum Lehrling.
      await tester.tap(find.text('Neu starten'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Neu starten'),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(ObjectProfile().budget, 20000 - cost);
      final restarted = ObjectProfile().personal.single;
      expect(restarted.rank, kRankApprentice);
      expect(restarted.levelValue, 1);
      expect(restarted.currentXPValue, 0);
      // Die Aktion ist danach verschwunden (Anzeige folgt der neuen Instanz).
      expect(find.text('Karriere-Neustart'), findsNothing);
    },
  );
}
