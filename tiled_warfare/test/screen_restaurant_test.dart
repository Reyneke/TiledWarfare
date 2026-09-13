import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/l10n/app_localizations.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/models/restaurant_upgrade.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/objects/player_objects/object_line_cook.dart';
import 'package:tiled_warfare/screens/screen_restaurant.dart';
import 'package:tiled_warfare/services/economy_balance.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget app(Widget home) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: home,
      );

  void loadProfile({
    int budget = 10000,
    Map<UpgradeType, int> upgrades = const {},
    DateTime? rebrandingPenaltyUntil,
    String? logoPath,
    List<StaffData>? staff,
  }) {
    ObjectProfile().loadFromData(
      ProfileData(
        id: 1,
        name: 'Testprofil',
        creationDate: DateTime(2026, 1, 1),
        restaurants: [
          RestaurantData(
            id: 1,
            name: 'Testrestaurant',
            district: 'Harlem',
            budget: budget,
            logoPath: logoPath,
            upgrades: upgrades,
            rebrandingPenaltyUntil: rebrandingPenaltyUntil,
            staff: staff,
          ),
        ],
      ),
      restaurantId: 1,
    );
  }

  testWidgets('zeigt die vier Reiter', (tester) async {
    loadProfile();

    await tester.pumpWidget(app(const ScreenRestaurant()));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Aktives Personal'), findsOneWidget);
    expect(find.text('Teamarzt'), findsOneWidget);
    expect(find.text('Erweiterungen'), findsOneWidget);
    expect(find.text('Karte & Gefecht'), findsOneWidget);
  });

  testWidgets('Erweiterungs-Reiter zeigt die Erweiterungen', (tester) async {
    loadProfile(upgrades: const {UpgradeType.signage: 1});

    await tester.pumpWidget(app(const ScreenRestaurant()));
    await tester.pump();

    await tester.tap(find.text('Erweiterungen'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Restauranterweiterungen'), findsOneWidget);
    expect(find.text('Werbeplakate'), findsOneWidget);
  });

  testWidgets('zeigt Permadeath-Dialog bei Bankrott', (tester) async {
    loadProfile(budget: -25000);

    await tester.pumpWidget(app(const ScreenRestaurant()));
    // Post-Frame-Callback (Bankrott-Prüfung) + Dialogaufbau.
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Bankrott!'), findsOneWidget);
  });

  testWidgets('zeigt aktiven Rebranding-Malus', (tester) async {
    loadProfile(
      rebrandingPenaltyUntil: DateTime.now().add(const Duration(days: 3)),
    );

    await tester.pumpWidget(app(const ScreenRestaurant()));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Rebranding aktiv'), findsOneWidget);
  });

  testWidgets('ohne Malus kein Rebranding-Hinweis', (tester) async {
    loadProfile();

    await tester.pumpWidget(app(const ScreenRestaurant()));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Rebranding aktiv'), findsNothing);
  });

  testWidgets('Header nutzt das Restaurant-Logo aus dem Singleton (V4)',
      (tester) async {
    loadProfile(logoPath: 'profiles/1/restaurant_1.png');

    await tester.pumpWidget(app(const ScreenRestaurant()));
    await tester.pump();

    expect(tester.takeException(), isNull);
    // Das Widget hält keinen eigenen Bildzustand mehr – die Quelle ist der
    // Singleton (V4).
    expect(ObjectProfile().hasCustomImage, isTrue);
    expect(ObjectProfile().headerImagePath, 'profiles/1/restaurant_1.png');
  });

  testWidgets('ohne Logo zeigt der Header die Küchen-Grafik (V4)',
      (tester) async {
    loadProfile();

    await tester.pumpWidget(app(const ScreenRestaurant()));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(ObjectProfile().hasCustomImage, isFalse);
    expect(
      ObjectProfile().headerImagePath,
      ObjectProfile().activeCuisine.tokenImagePath,
    );
  });

  testWidgets('Fortbildung: Button ab Lehrling sichtbar, Kader wandert mit',
      (tester) async {
    loadProfile(
      staff: [
        StaffData(
          name: 'Apprentice: Testkoch',
          imagePath: 'assets/images/token/token_cook_basic.png',
          type: 'apprentice',
          levelValue: 5,
        ),
      ],
    );

    await tester.pumpWidget(app(const ScreenRestaurant()));
    await tester.pump();

    // In den Kader aufnehmen (Checkbox der Personal-Zeile).
    final checkbox = find.byType(Checkbox);
    await tester.ensureVisible(checkbox);
    await tester.pumpAndSettle();
    await tester.tap(checkbox);
    await tester.pump();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);

    // Fortbilden: Button → Bestätigungsdialog → Bestätigen.
    final promoteButton = find.byTooltip('Zum Line Cook fortbilden');
    await tester.ensureVisible(promoteButton);
    await tester.pumpAndSettle();
    await tester.tap(promoteButton);
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Zum Line Cook fortbilden'),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(ObjectProfile().personal.single, isA<ObjectLineCook>());
    expect(
      ObjectProfile().budget,
      10000 - EconomyBalance.upgradeToLineCookCost,
    );
    // Der Kader-Haken hängt am neuen Line Cook, nicht am alten Lehrling.
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
  });

  testWidgets('Fortbildung unter Level 5 zeigt eine Fehlermeldung',
      (tester) async {
    loadProfile(
      staff: [
        StaffData(
          name: 'Apprentice: Testkoch',
          imagePath: 'assets/images/token/token_cook_basic.png',
          type: 'apprentice',
          levelValue: 4,
        ),
      ],
    );

    await tester.pumpWidget(app(const ScreenRestaurant()));
    await tester.pump();

    final promoteButton = find.byTooltip('Zum Line Cook fortbilden');
    await tester.ensureVisible(promoteButton);
    await tester.pumpAndSettle();
    await tester.tap(promoteButton);
    await tester.pump();

    expect(find.text('Fortbildung erst ab Level 5 möglich!'), findsOneWidget);
  });
}
