import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/l10n/app_localizations.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/models/restaurant_upgrade.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/screens/screen_restaurant.dart';

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
            upgrades: upgrades,
            rebrandingPenaltyUntil: rebrandingPenaltyUntil,
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
}
