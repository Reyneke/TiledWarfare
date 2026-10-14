import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/l10n/app_localizations.dart';
import 'package:tiled_warfare/models/management_feature.dart';
import 'package:tiled_warfare/models/management_role.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/screens/screen_hire_and_fire.dart';
import 'package:tiled_warfare/services/economy_balance.dart';

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
    // Exact matches: the randomly generated pool may contain surnames like
    // "Rossi"/"Bianchi", so `textContaining` would be flaky.
    expect(find.text('Rossi'), findsOneWidget);
    expect(find.text('Bianchi'), findsOneWidget);
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

  testWidgets('Hilfs-/Service-Rollen sind anstellbar (V10, Phase 6)',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    loadProfile();

    await tester.pumpWidget(app(const ScreenHireAndFire()));
    await tester.pump();

    expect(tester.takeException(), isNull);
    // Der Rollen-Abschnitt ist sichtbar (Auswahlkarten inkl. Communard).
    expect(find.text('Hilfs- und Service-Rollen'), findsOneWidget);
    expect(find.text('Communard (Staff cook)'), findsOneWidget);

    // Erste Rolle anstellen.
    final hireButton = find.widgetWithText(FilledButton, 'Anstellen').first;
    await tester.ensureVisible(hireButton);
    await tester.pumpAndSettle();
    await tester.tap(hireButton);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(ObjectProfile().supportStaffCount, 1);
    // Mit angestellter Rolle erscheint die Gesamtwochenlast.
    expect(find.textContaining('Gesamtwochenlast'), findsOneWidget);
  });

  testWidgets('Entlassen fragt nach und ist ohne Bestätigung folgenlos (P4)',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    loadProfile();

    await tester.pumpWidget(app(const ScreenHireAndFire()));
    await tester.pump();

    // Rolle anstellen (wie oben; die Entlassung hängt an der Karte).
    final hireButton = find.widgetWithText(FilledButton, 'Anstellen').first;
    await tester.ensureVisible(hireButton);
    await tester.pumpAndSettle();
    await tester.tap(hireButton);
    await tester.pumpAndSettle();
    expect(ObjectProfile().supportStaffCount, 1);

    // Entlassen ohne Bestätigung: der Dialog warnt, die Rolle bleibt.
    final fireButton = find.widgetWithText(OutlinedButton, 'Entlassen').first;
    await tester.ensureVisible(fireButton);
    await tester.pumpAndSettle();
    await tester.tap(fireButton);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Eine Entlassung wird nicht erstattet'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Abbrechen'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(ObjectProfile().supportStaffCount, 1);

    // Bestätigen entfernt die Rolle (keine Rückerstattung).
    await tester.tap(fireButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Entlassen'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(ObjectProfile().supportStaffCount, 0);
  });

  testWidgets('Aktivierung nennt Wirkung, Kosten, Träger und Dauer (P4)',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    loadProfile();

    await tester.pumpWidget(app(const ScreenHireAndFire()));
    await tester.pump();

    // Rechtsanwalt anstellen – er trägt den ziel-losen „Winkelzug“ (E15).
    final lawyerCard = find
        .ancestor(of: find.text('Rechtsanwalt'), matching: find.byType(Card))
        .first;
    final hireButton = find.descendant(
      of: lawyerCard,
      matching: find.byType(FilledButton),
    );
    await tester.ensureVisible(hireButton);
    await tester.pumpAndSettle();
    await tester.tap(hireButton);
    await tester.pumpAndSettle();
    expect(
      ObjectProfile().hasManagementRole(ManagementRole.lawyer),
      isTrue,
      reason: 'Karte der angestellten Management-Rolle ohne Layout-Overflow',
    );
    expect(tester.takeException(), isNull, reason: 'nach dem Anstellen');

    // Aktivieren: erst der Bestätigungsdialog, dann die Buchung.
    final activateButton = find.widgetWithText(
      TextButton,
      'Aktivierung: ${EconomyBalance.legalTrickCost} €',
    );
    await tester.ensureVisible(activateButton);
    await tester.pumpAndSettle();
    await tester.tap(activateButton);
    await tester.pumpAndSettle();

    expect(find.text('Feature aktivieren?'), findsOneWidget);
    expect(
      find.textContaining('Einmalkosten: ${EconomyBalance.legalTrickCost} €'),
      findsOneWidget,
    );
    expect(find.textContaining('Träger:'), findsOneWidget);
    expect(find.textContaining('Aktiv:'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Dialog ohne Layout-Overflow');

    // Abbrechen lässt alles unangetastet.
    final budgetBefore = ObjectProfile().budget;
    await tester.tap(find.widgetWithText(TextButton, 'Abbrechen'));
    await tester.pumpAndSettle();
    expect(
      ObjectProfile().managementFeatureIsActive(ManagementFeature.legalTrick),
      isFalse,
    );
    expect(ObjectProfile().budget, budgetBefore);

    // Bestätigen aktiviert und bucht die Einmalkosten sofort.
    await tester.tap(activateButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Feature aktivieren'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      ObjectProfile().managementFeatureIsActive(ManagementFeature.legalTrick),
      isTrue,
    );
    expect(
      ObjectProfile().budget,
      budgetBefore - EconomyBalance.legalTrickCost,
    );
  });
}
