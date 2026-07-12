import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// Der Titel der App
  ///
  /// In de, this message translates to:
  /// **'Tiled Warfare'**
  String get appTitle;

  /// Abbrechen-Button in Dialogen
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get cancel;

  /// Löschen-Button in Dialogen
  ///
  /// In de, this message translates to:
  /// **'Löschen'**
  String get delete;

  /// Speichern-Button in Dialogen
  ///
  /// In de, this message translates to:
  /// **'Speichern'**
  String get save;

  /// Erstellen-Button in Dialogen
  ///
  /// In de, this message translates to:
  /// **'Erstellen'**
  String get create;

  /// Edit-Button
  ///
  /// In de, this message translates to:
  /// **'Bearbeiten'**
  String get edit;

  /// Titel im Dialog zum Erstellen eines neuen Profils
  ///
  /// In de, this message translates to:
  /// **'Neues Profil'**
  String get newProfile;

  /// Titel im Dialog zum Umbenennen eines Profils
  ///
  /// In de, this message translates to:
  /// **'Profil umbenennen'**
  String get renameProfile;

  /// Titel im Bestätigungsdialog zum Löschen eines Profils
  ///
  /// In de, this message translates to:
  /// **'Profil löschen'**
  String get deleteProfile;

  /// Bestätigungstext zum Löschen eines Profils
  ///
  /// In de, this message translates to:
  /// **'Soll das Profil \"{name}\" wirklich gelöscht werden?\nAlle zugehörigen Daten werden unwiderruflich entfernt.'**
  String deleteProfileConfirm(String name);

  /// Label für das Profilname-Textfeld
  ///
  /// In de, this message translates to:
  /// **'Profilname'**
  String get profileName;

  /// Platzhaltertext für den Spielernamen
  ///
  /// In de, this message translates to:
  /// **'Name des Spielers'**
  String get playerNameHint;

  /// Validierungsfehler, wenn kein Name eingegeben wurde
  ///
  /// In de, this message translates to:
  /// **'Bitte gib einen Namen ein.'**
  String get pleaseEnterName;

  /// Titel im Dialog zum Erstellen eines neuen Restaurants
  ///
  /// In de, this message translates to:
  /// **'Neues Restaurant'**
  String get newRestaurant;

  /// Titel im Dialog zum Ändern des Restaurantnamens
  ///
  /// In de, this message translates to:
  /// **'Restaurantnamen ändern'**
  String get renameRestaurant;

  /// Titel im Bestätigungsdialog zum Löschen eines Restaurants
  ///
  /// In de, this message translates to:
  /// **'Restaurant löschen'**
  String get deleteRestaurant;

  /// Bestätigungstext zum Löschen eines Restaurants
  ///
  /// In de, this message translates to:
  /// **'Soll das Restaurant \"{name}\" wirklich gelöscht werden?'**
  String deleteRestaurantConfirm(String name);

  /// Label für das Restaurantname-Textfeld
  ///
  /// In de, this message translates to:
  /// **'Restaurantname'**
  String get restaurantName;

  /// Platzhaltertext für den Restaurantnamen
  ///
  /// In de, this message translates to:
  /// **'Name des Restaurants'**
  String get restaurantNameHint;

  /// Platzhaltertext beim Umbenennen
  ///
  /// In de, this message translates to:
  /// **'Neuen Namen eingeben'**
  String get newNameHint;

  /// Überschrift für den Profilbereich
  ///
  /// In de, this message translates to:
  /// **'Profile'**
  String get profileSection;

  /// Tooltip für den 'Neues Profil'-Button
  ///
  /// In de, this message translates to:
  /// **'Neues Profil'**
  String get newProfileTooltip;

  /// Tooltip für den 'Profil umbenennen'-Button
  ///
  /// In de, this message translates to:
  /// **'Profil umbenennen'**
  String get renameProfileTooltip;

  /// Tooltip für den 'Profil löschen'-Button
  ///
  /// In de, this message translates to:
  /// **'Profil löschen'**
  String get deleteProfileTooltip;

  /// Text, wenn noch keine Profile existieren
  ///
  /// In de, this message translates to:
  /// **'Noch keine Profile vorhanden.\nErstelle ein neues Profil!'**
  String get noProfilesYet;

  /// Untertitel eines Profils mit ID, Erstellungsdatum und Restaurantanzahl
  ///
  /// In de, this message translates to:
  /// **'ID: {id}\nErstellt: {date}\nRestaurants: {count}'**
  String profileSubtitle(int id, String date, int count);

  /// Snackbar-Fehlermeldung beim Profilbild-Laden
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden des Profilbildes.'**
  String get profileImageError;

  /// Überschrift für den Restaurantbereich
  ///
  /// In de, this message translates to:
  /// **'Restaurants'**
  String get restaurantSection;

  /// Tooltip für den 'Neues Restaurant'-Button
  ///
  /// In de, this message translates to:
  /// **'Neues Restaurant'**
  String get newRestaurantTooltip;

  /// Tooltip für den 'Restaurant löschen'-Button
  ///
  /// In de, this message translates to:
  /// **'Restaurant löschen'**
  String get deleteRestaurantTooltip;

  /// Hinweis, wenn noch kein Profil ausgewählt wurde
  ///
  /// In de, this message translates to:
  /// **'Wähle zuerst ein Profil aus.'**
  String get selectProfileFirst;

  /// Text, wenn noch keine Restaurants existieren
  ///
  /// In de, this message translates to:
  /// **'Noch keine Restaurants vorhanden.\nErstelle ein neues Restaurant!'**
  String get noRestaurantsYet;

  /// Button-Text zum Einloggen mit Profilnamen
  ///
  /// In de, this message translates to:
  /// **'Einloggen als {name}'**
  String loginAs(String name);

  /// Button-Text, wenn kein Profil ausgewählt ist
  ///
  /// In de, this message translates to:
  /// **'Bitte Profil auswählen'**
  String get selectProfilePrompt;

  /// Tooltip für den Theme-Umschalt-Button
  ///
  /// In de, this message translates to:
  /// **'Theme wechseln ({mode})'**
  String themeToggle(String mode);

  /// AppBar-Titel für den Personalverwaltungs-Screen
  ///
  /// In de, this message translates to:
  /// **'Personalverwaltung'**
  String get personnelManagement;

  /// Tooltip für den Pool-Neugenerierungs-Button
  ///
  /// In de, this message translates to:
  /// **'Pool neu generieren'**
  String get regeneratePool;

  /// Überschrift für angestelltes Personal
  ///
  /// In de, this message translates to:
  /// **'Angestellte ({count})'**
  String hiredPersonnel(int count);

  /// Überschrift für verfügbare Kandidaten
  ///
  /// In de, this message translates to:
  /// **'Verfügbare Kandidaten ({count})'**
  String availableCandidates(int count);

  /// Text, wenn keine Kandidaten verfügbar sind
  ///
  /// In de, this message translates to:
  /// **'Keine Kandidaten verfügbar.'**
  String get noCandidatesAvailable;

  /// Button zum Generieren eines neuen Kandidaten-Pools
  ///
  /// In de, this message translates to:
  /// **'Neuen Pool generieren'**
  String get generateNewPool;

  /// Medic-Qualität: Niedrig
  ///
  /// In de, this message translates to:
  /// **'Niedrig'**
  String get qualityLow;

  /// Medic-Qualität: Mittel
  ///
  /// In de, this message translates to:
  /// **'Mittel'**
  String get qualityMedium;

  /// Medic-Qualität: Hoch
  ///
  /// In de, this message translates to:
  /// **'Hoch'**
  String get qualityHigh;

  /// Wöchentliche Kosten eines Angestellten
  ///
  /// In de, this message translates to:
  /// **'{cost} € / Woche'**
  String costPerWeek(int cost);

  /// Button zum Entlassen von Personal
  ///
  /// In de, this message translates to:
  /// **'Entlassen'**
  String get fire;

  /// Button zum Anstellen von Personal
  ///
  /// In de, this message translates to:
  /// **'Anstellen'**
  String get hire;

  /// Fallback-Name für das Restaurant
  ///
  /// In de, this message translates to:
  /// **'Restaurant'**
  String get restaurant;

  /// Fallback-Name für den Spieler
  ///
  /// In de, this message translates to:
  /// **'Spieler'**
  String get player;

  /// Budget-Anzeige
  ///
  /// In de, this message translates to:
  /// **'{budget} €'**
  String budgetLabel(int budget);

  /// Überschrift für die Personal-Liste
  ///
  /// In de, this message translates to:
  /// **'Personal ({count})'**
  String personnelCount(int count);

  /// Text, wenn noch kein Personal eingestellt wurde
  ///
  /// In de, this message translates to:
  /// **'Noch kein Personal eingestellt.\nHeuere einen Lehrling an!'**
  String get noPersonnelYet;

  /// Button zum Anheuern von neuem Personal
  ///
  /// In de, this message translates to:
  /// **'Neues Personal anheuern'**
  String get hireNewPersonnel;

  /// Snackbar-Fehlermeldung, wenn das Budget nicht reicht
  ///
  /// In de, this message translates to:
  /// **'Budget reicht nicht zum Anheuern!'**
  String get notEnoughBudget;

  /// Überschrift für die Karten-Liste
  ///
  /// In de, this message translates to:
  /// **'Verfügbare Karten'**
  String get availableMaps;

  /// Fehlermeldung beim Laden der Karten
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden der Karten:\n{error}'**
  String mapLoadError(String error);

  /// Text, wenn keine Karten gefunden wurden
  ///
  /// In de, this message translates to:
  /// **'Keine Karten gefunden.'**
  String get noMapsFound;

  /// Button zum Starten des Gefechts
  ///
  /// In de, this message translates to:
  /// **'Gefecht starten'**
  String get startBattle;

  /// Snackbar-Fehlermeldung beim Restaurantlogo-Laden
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden des Restaurantlogos.'**
  String get restaurantLogoError;

  /// Tooltip für den 'Profilbild ändern'-Button
  ///
  /// In de, this message translates to:
  /// **'Profilbild ändern'**
  String get changeProfileImage;

  /// Tooltip für den 'Personal verwalten'-Button
  ///
  /// In de, this message translates to:
  /// **'Personal verwalten (anheuern/entlassen)'**
  String get managePersonnel;

  /// Titel für den Charakter-Detail-Screen
  ///
  /// In de, this message translates to:
  /// **'Charakterdetails'**
  String get characterDetail;

  /// Rangbezeichnung: Line Cook
  ///
  /// In de, this message translates to:
  /// **'Line Cook'**
  String get rankLineCook;

  /// Rangbezeichnung: Apprentice
  ///
  /// In de, this message translates to:
  /// **'Apprentice'**
  String get rankApprentice;

  /// Level-Anzeige
  ///
  /// In de, this message translates to:
  /// **'Level {value}'**
  String level(int value);

  /// Trefferpunkte/Lebenspunkte-Anzeige
  ///
  /// In de, this message translates to:
  /// **'LP: {value}'**
  String hitPoints(int value);

  /// Kampfwerte-Aufstellung
  ///
  /// In de, this message translates to:
  /// **'⚔️ {attack}  🛡️ {defense}  🏃 {movement}  💥 {damage}  🎯 {range}'**
  String statsLine(
    int attack,
    int defense,
    int movement,
    int damage,
    int range,
  );

  /// K/D-Ratio-Anzeige
  ///
  /// In de, this message translates to:
  /// **'K/D: {ratio}'**
  String kdRatio(String ratio);

  /// Match-Statistiken Siege/Niederlagen/Unentschieden
  ///
  /// In de, this message translates to:
  /// **'Matches: {wins}S / {losses}N / {draws}U'**
  String matchStats(int wins, int losses, int draws);

  /// Hinweis, wenn noch keine Match-Daten vorhanden sind
  ///
  /// In de, this message translates to:
  /// **'Noch keine Match-Daten'**
  String get noMatchData;

  /// Überschrift für die Match-Historie-Tabelle
  ///
  /// In de, this message translates to:
  /// **'Match-Historie'**
  String get matchHistory;

  /// Text, wenn keine Match-Historie vorhanden ist
  ///
  /// In de, this message translates to:
  /// **'Keine Match-Historie vorhanden.'**
  String get noMatchHistory;

  /// Tabellenkopf: Datum
  ///
  /// In de, this message translates to:
  /// **'Datum'**
  String get tableDate;

  /// Tabellenkopf: Gegner
  ///
  /// In de, this message translates to:
  /// **'Gegner'**
  String get tableOpponent;

  /// Tabellenkopf: Ergebnis
  ///
  /// In de, this message translates to:
  /// **'Ergebnis'**
  String get tableResult;

  /// Tabellenkopf: K/D-Ratio
  ///
  /// In de, this message translates to:
  /// **'K/D'**
  String get tableKD;

  /// Tabellenkopf: Ereignisse
  ///
  /// In de, this message translates to:
  /// **'Ereignisse'**
  String get tableEvents;

  /// Label für Teamarzt-Aktionen
  ///
  /// In de, this message translates to:
  /// **'Teamarzt:'**
  String get teamMedic;

  /// Button zum Behandeln durch den Teamarzt
  ///
  /// In de, this message translates to:
  /// **'Behandeln'**
  String get treat;

  /// Snackbar-Text bei erfolgreicher Behandlung
  ///
  /// In de, this message translates to:
  /// **'{name} wurde behandelt.'**
  String treatmentSuccess(String name);

  /// Snackbar-Text bei fehlgeschlagener Behandlung
  ///
  /// In de, this message translates to:
  /// **'Behandlung fehlgeschlagen.'**
  String get treatmentFailed;

  /// Button für die Notfall-Spritze
  ///
  /// In de, this message translates to:
  /// **'Notfall-Spritze'**
  String get emergencyShot;

  /// Snackbar-Text bei erfolgreicher Notfall-Spritze
  ///
  /// In de, this message translates to:
  /// **'{name} wurde eine Notfall-Spritze verabreicht.'**
  String emergencyShotSuccess(String name);

  /// Snackbar-Text bei fehlgeschlagener Notfall-Spritze
  ///
  /// In de, this message translates to:
  /// **'Notfall-Spritze fehlgeschlagen.'**
  String get emergencyShotFailed;

  /// XP-Balken-Beschriftung
  ///
  /// In de, this message translates to:
  /// **'XP: {current} / {threshold}'**
  String xpLabel(int current, int threshold);

  /// Hinweis, wenn ein Level-Aufstieg möglich ist
  ///
  /// In de, this message translates to:
  /// **'Level-Aufstieg möglich!'**
  String get levelUpPossible;

  /// Info-Button im Kontextmenü
  ///
  /// In de, this message translates to:
  /// **'Info'**
  String get info;

  /// Schließen-Button
  ///
  /// In de, this message translates to:
  /// **'Schließen'**
  String get close;

  /// Nahkampf-Aktion
  ///
  /// In de, this message translates to:
  /// **'Nahkampf'**
  String get melee;

  /// Fernkampf-Aktion
  ///
  /// In de, this message translates to:
  /// **'Fernkampf'**
  String get ranged;

  /// Typbezeichnung für Apprentice-Charaktere
  ///
  /// In de, this message translates to:
  /// **'Apprentice'**
  String get apprenticeLabel;

  /// Label für gefallene Charaktere
  ///
  /// In de, this message translates to:
  /// **'Ausgefallen'**
  String get fallenLabel;

  /// Tooltip für den Teamarzt-Button
  ///
  /// In de, this message translates to:
  /// **'Teamarzt einsetzen'**
  String get medicAssignTooltip;

  /// Charakter-Info-Zeile
  ///
  /// In de, this message translates to:
  /// **'AW: {attack} | VW: {defense} | BW: {movement} | SW: {damage} | RW: {range} | LP: {hp}'**
  String characterInfo(
    int attack,
    int defense,
    int movement,
    int damage,
    int range,
    int hp,
  );
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
