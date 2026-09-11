import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/l10n/app_localizations.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/screens/screen_hire_and_fire.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget app(Widget home) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: home,
      );

  void loadProfile({List<MedicData> medics = const []}) {
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
            budget: 10000,
            medics: medics,
          ),
        ],
      ),
      restaurantId: 1,
    );
  }

  testWidgets('zeigt angeheuerte Ärzte samt Gesamtwochenlast', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    loadProfile(medics: [
      MedicData(
        id: 1,
        name: 'Rossi',
        quality: 'mittel',
        costPerWeek: 1000,
        enneagramProfileName: 'Der Chaot',
      ),
      MedicData(
        id: 2,
        name: 'Bianchi',
        quality: 'niedrig',
        costPerWeek: 500,
        enneagramProfileName: 'Der Helfer',
      ),
    ]);

    await tester.pumpWidget(app(const ScreenHireAndFire()));
    await tester.pump();

    expect(tester.takeException(), isNull);
    // Gesamtwochenlast 1000 + 500 = 1500 €
    expect(find.textContaining('Gesamtwochenlast'), findsOneWidget);
    expect(find.textContaining('1500'), findsWidgets);
    expect(find.textContaining('Rossi'), findsOneWidget);
    expect(find.textContaining('Bianchi'), findsOneWidget);
  });

  testWidgets('ohne Ärzte wird keine Wochenlast angezeigt', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    loadProfile();

    await tester.pumpWidget(app(const ScreenHireAndFire()));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Gesamtwochenlast'), findsNothing);
  });
}
