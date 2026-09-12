import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/l10n/app_localizations.dart';
import 'package:tiled_warfare/main_app.dart';
import 'package:tiled_warfare/models/cuisine.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/screens/screen_battle_result.dart';
import 'package:tiled_warfare/screens/screen_restaurant.dart';
import 'package:tiled_warfare/services/economy_balance.dart';

/// Smoke-Tests: booten die echte App bzw. den Restaurant-Hauptfluss und
/// stellen sicher, dass keine unbehandelte Exception entsteht. Sie ergänzen
/// die Unit-/Widget-Tests um einen schnellen "Läuft die App überhaupt?"-Check.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget app(Widget home) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: home,
      );

  testWidgets('App bootet (MainApp → Start-Screen) ohne Exception',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MainApp());
    // Start-Screen lädt Profile (Dateisystem) und Stadtteile (Asset), daher
    // mehrere Frames statt pumpAndSettle (Ladeindikator animiert dauerhaft).
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Tiled Warfare'), findsWidgets);
  });

  testWidgets('Restaurant-Hauptfluss (Reiter, Arztverwaltung, Ergebnis)',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    ObjectProfile().loadFromData(
      ProfileData(
        id: 1,
        name: 'Smoke-Profil',
        creationDate: DateTime(2026, 1, 1),
        restaurants: [
          RestaurantData(
            id: 1,
            name: 'Smoke-Restaurant',
            district: 'Harlem',
            cuisine: Cuisine.japanese,
            budget: EconomyBalance.startBudget,
            // Ein Charakter, damit die Personal-Liste (Küchen-Avatar, § 9)
            // tatsächlich gerendert wird.
            staff: [
              StaffData(
                name: 'Smoke-Koch',
                imagePath: Cuisine.japanese.tokenImagePath,
                type: 'apprentice',
                status: 'ready',
              ),
            ],
          ),
        ],
      ),
      restaurantId: 1,
    );

    await tester.pumpWidget(app(const ScreenRestaurant()));
    await tester.pump();
    expect(tester.takeException(), isNull);

    // Alle vier Reiter durchschalten. Nach dem Antippen muss die
    // TabBarView-Animation ablaufen, sonst ist der Ziel-Inhalt noch offstage.
    for (final tab in const [
      'Teamarzt',
      'Erweiterungen',
      'Karte & Gefecht',
      'Aktives Personal',
    ]) {
      await tester.tap(find.text(tab));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    }

    // Arztverwaltung öffnen (verlässt den ScreenRestaurant-Flow).
    await tester.tap(find.text('Teamarzt'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final managePersonnel = find.textContaining('Personal verwalten');
    expect(managePersonnel, findsOneWidget);
    await tester.ensureVisible(managePersonnel);
    await tester.tap(managePersonnel);
    await tester.pump();
    expect(tester.takeException(), isNull);

    // Gefechtsergebnis inkl. Wirtschaftsabrechnung (Belohnung + Beute).
    await tester.pumpWidget(
      app(const ScreenBattleResult(
        playerWon: true,
        opponentName: 'Smoke-Gegner',
        enemyLoot: 200,
      )),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
