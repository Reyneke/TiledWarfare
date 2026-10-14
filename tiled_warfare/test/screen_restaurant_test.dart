import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/l10n/app_localizations.dart';
import 'package:tiled_warfare/models/management_feature.dart';
import 'package:tiled_warfare/models/management_role.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/models/restaurant_upgrade.dart';
import 'package:tiled_warfare/models/staff_entry.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/objects/player_objects/object_line_cook.dart';
import 'package:tiled_warfare/screens/screen_restaurant.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/game_clock_service.dart';

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
    List<StaffEntryData>? staffEntries,
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
            staffEntries: staffEntries,
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

  testWidgets('Keller-Kachel ist ausbaubar (V1-Paket, § 10)', (tester) async {
    loadProfile();
    final profile = ObjectProfile();

    await tester.pumpWidget(app(const ScreenRestaurant()));
    await tester.pump();

    await tester.tap(find.text('Erweiterungen'));
    await tester.pumpAndSettle();

    final cellarCard = find.ancestor(
      of: find.text('Wein-/Getränkekeller'),
      matching: find.byType(Card),
    );
    expect(cellarCard, findsOneWidget);

    final buyButton = find.descendant(
      of: cellarCard,
      matching: find.widgetWithText(FilledButton, 'Ausbauen'),
    );
    await tester.ensureVisible(buyButton);
    await tester.pumpAndSettle();
    await tester.tap(buyButton);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(profile.upgradeLevel(UpgradeType.cellar), 1);
    expect(profile.budget, 10000 - 180);
  });

  testWidgets('Kühlhaus-Kachel ist ausbaubar (V1-Paket, § 10)',
      (tester) async {
    loadProfile();
    final profile = ObjectProfile();

    await tester.pumpWidget(app(const ScreenRestaurant()));
    await tester.pump();

    await tester.tap(find.text('Erweiterungen'));
    await tester.pumpAndSettle();

    final coldRoomCard = find.ancestor(
      of: find.text('Kühlhaus/Kühlkette'),
      matching: find.byType(Card),
    );
    expect(coldRoomCard, findsOneWidget);

    final buyButton = find.descendant(
      of: coldRoomCard,
      matching: find.widgetWithText(FilledButton, 'Ausbauen'),
    );
    await tester.ensureVisible(buyButton);
    await tester.pumpAndSettle();
    await tester.tap(buyButton);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(profile.upgradeLevel(UpgradeType.coldRoom), 1);
    expect(profile.budget, 10000 - 160);
  });

  testWidgets('Erste-Hilfe-Kachel ist ausbaubar (V1-Paket, § 10)',
      (tester) async {
    loadProfile();
    final profile = ObjectProfile();

    await tester.pumpWidget(app(const ScreenRestaurant()));
    await tester.pump();

    await tester.tap(find.text('Erweiterungen'));
    await tester.pumpAndSettle();

    final firstAidCard = find.ancestor(
      of: find.text('Erste-Hilfe-Station'),
      matching: find.byType(Card),
    );
    expect(firstAidCard, findsOneWidget);

    final buyButton = find.descendant(
      of: firstAidCard,
      matching: find.widgetWithText(FilledButton, 'Ausbauen'),
    );
    await tester.ensureVisible(buyButton);
    await tester.pumpAndSettle();
    await tester.tap(buyButton);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(profile.upgradeLevel(UpgradeType.firstAid), 1);
    expect(profile.budget, 10000 - 250);
  });

  testWidgets('Ruheraum-Kachel ist ausbaubar (V1-Paket, § 10)',
      (tester) async {
    loadProfile();
    final profile = ObjectProfile();

    await tester.pumpWidget(app(const ScreenRestaurant()));
    await tester.pump();

    await tester.tap(find.text('Erweiterungen'));
    await tester.pumpAndSettle();

    final loungeCard = find.ancestor(
      of: find.text('Ruheraum/Lounge'),
      matching: find.byType(Card),
    );
    expect(loungeCard, findsOneWidget);

    final buyButton = find.descendant(
      of: loungeCard,
      matching: find.widgetWithText(FilledButton, 'Ausbauen'),
    );
    await tester.ensureVisible(buyButton);
    await tester.pumpAndSettle();
    await tester.tap(buyButton);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(profile.upgradeLevel(UpgradeType.lounge), 1);
    expect(profile.budget, 10000 - 180);
  });

  testWidgets('Verkaufen fragt nach und erstattet erst nach Bestätigung',
      (tester) async {
    loadProfile(upgrades: const {UpgradeType.signage: 1});
    final profile = ObjectProfile();
    final budgetBefore = profile.budget;

    await tester.pumpWidget(app(const ScreenRestaurant()));
    await tester.pump();

    await tester.tap(find.text('Erweiterungen'));
    await tester.pumpAndSettle();

    // „Verkaufen“-Button der Werbeplakate-Kachel (Stufe 1 → aktiv).
    final sellButton = find.descendant(
      of: find.ancestor(
        of: find.text('Werbeplakate'),
        matching: find.byType(Card),
      ),
      matching: find.widgetWithText(OutlinedButton, 'Verkaufen'),
    );
    expect(sellButton, findsOneWidget);

    // Abbruch: nichts wird gebucht (signage Stufe 1: 50 % von 150 € = 75 €).
    await tester.ensureVisible(sellButton);
    await tester.pumpAndSettle();
    await tester.tap(sellButton);
    await tester.pumpAndSettle();
    expect(find.textContaining('Rückerstattung: 75 €'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Abbrechen'));
    await tester.pumpAndSettle();
    expect(profile.upgradeLevel(UpgradeType.signage), 1);
    expect(profile.budget, budgetBefore);

    // Bestätigung: Stufe fällt weg, Erstattung wird gutgeschrieben.
    await tester.ensureVisible(sellButton);
    await tester.pumpAndSettle();
    await tester.tap(sellButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Verkaufen'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(profile.upgradeLevel(UpgradeType.signage), 0);
    expect(profile.budget, budgetBefore + 75);
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

  testWidgets('zeigt den Countdown laufender Features außerhalb der Karte (P4)',
      (tester) async {
    loadProfile(
      staffEntries: [
        StaffEntryData(
          id: 1,
          name: 'Mia',
          kind: RoleKind.management,
          role: ManagementRole.socialMediaManager.name,
          costPerWeek: 180,
          activeFeature: ManagementFeature.prCampaign.name,
          featureTargetId: 5,
          featureActivatedAt: DateTime.now(),
        ),
      ],
    );

    await tester.pumpWidget(app(const ScreenRestaurant()));
    await tester.pump();

    expect(tester.takeException(), isNull);
    // Der Countdown steht in der Kopfzeile (nicht in der Personal-Karte) und
    // nennt Träger, Feature und Restlaufzeit.
    expect(find.textContaining('Laufende Features'), findsOneWidget);
    expect(find.textContaining('PR-Kampagne'), findsOneWidget);
    expect(find.textContaining('Aktiv bis'), findsOneWidget);
  });
  testWidgets('Wochenbericht schlüsselt jeden Block auf (P6, 4.2/#5)', (tester) async {
    loadProfile();
    ObjectProfile().pendingCatchUpResult = WeeklyTickResult(
      weeks: 2,
      passiveIncome: 4000,
      medicCosts: 500,
      staffCosts: 700,
      upgradeUpkeep: 100,
      negativeInterest: 25,
      penaltyCosts: 3000,
      featureCosts: 150,
      prepaidFeatureCosts: 2500,
      rivalSabotageLosses: 120,
      budgetAfter: 8000,
      bankrupt: false,
      settlements: [
        WeekSettlement(
          weekIndex: 0,
          periodStart: DateTime(2026, 1, 1),
          periodEnd: DateTime(2026, 1, 8),
          income: 2000,
          medicCosts: 250,
          staffCosts: 350,
          upgradeUpkeep: 50,
          negativeInterest: 10,
          penaltyCosts: 3000,
          featureCosts: 75,
          prepaidFeatureCosts: 2500,
          rivalSabotageLoss: 120,
          budgetAfter: 7000,
        ),
        WeekSettlement(
          weekIndex: 1,
          periodStart: DateTime(2026, 1, 8),
          periodEnd: DateTime(2026, 1, 15),
          income: 2000,
          medicCosts: 250,
          staffCosts: 350,
          upgradeUpkeep: 50,
          negativeInterest: 15,
          budgetAfter: 8000,
        ),
      ],
    );

    await tester.pumpWidget(app(const ScreenRestaurant()));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Wochenbericht'), findsOneWidget);
    expect(find.text('Wochen-Aufschlüsselung'), findsOneWidget);

    // Ein Block je Woche, mit Zeitraum – Details erst beim Aufklappen.
    final firstWeek = find.text('Woche 1 (1.1.2026–8.1.2026)');
    expect(firstWeek, findsOneWidget);
    expect(find.text('Woche 2 (8.1.2026–15.1.2026)'), findsOneWidget);
    expect(find.textContaining('Einkommen +2000 €'), findsNothing);

    await tester.ensureVisible(firstWeek);
    await tester.tap(firstWeek);
    await tester.pumpAndSettle();

    // Alle Aufschlüsselungszeilen des Blocks sind sichtbar.
    expect(find.textContaining('Einkommen +2000 €'), findsOneWidget);
    expect(find.textContaining('Teamärzte −250 €'), findsOneWidget);
    expect(find.textContaining('Personal −350 €'), findsOneWidget);
    expect(find.textContaining('Unterhalt −50 €'), findsOneWidget);
    expect(find.textContaining('Zinsen −10 €'), findsOneWidget);
    expect(find.textContaining('Strafen −3000 €'), findsOneWidget);
    expect(find.textContaining('Features −75 €'), findsOneWidget);
    expect(find.textContaining('Feature-Einmalkosten (vorab gebucht) −2500 €'),
        findsOneWidget);
    expect(find.textContaining('Rivalen-Sabotage −120 €'), findsOneWidget);
    expect(find.textContaining('Budget danach 7000 €'), findsOneWidget);
  });


}
