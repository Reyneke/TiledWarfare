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

  /// Heading for the district (Stadtteil) selection
  ///
  /// In de, this message translates to:
  /// **'Stadtteile'**
  String get districtSection;

  /// Label showing the district of a restaurant
  ///
  /// In de, this message translates to:
  /// **'Stadtteil: {district}'**
  String districtLabel(String district);

  /// Action to found a new restaurant in a free district
  ///
  /// In de, this message translates to:
  /// **'Neues Restaurant gründen'**
  String get foundRestaurant;

  /// Badge for a dissolved (bankrupt) savegame
  ///
  /// In de, this message translates to:
  /// **'Aufgelöst'**
  String get dissolved;

  /// App-bar action to switch between savegames
  ///
  /// In de, this message translates to:
  /// **'Spielstand wechseln'**
  String get switchRestaurant;

  /// Error text when the districts could not be loaded
  ///
  /// In de, this message translates to:
  /// **'Stadtteile konnten nicht geladen werden:\n{error}'**
  String districtLoadError(String error);

  /// Error when founding in an already occupied district
  ///
  /// In de, this message translates to:
  /// **'In {district} gibt es bereits ein Restaurant.'**
  String districtOccupied(String district);

  /// Snackbar when there are no other savegames to switch to
  ///
  /// In de, this message translates to:
  /// **'Keine weiteren Spielstände vorhanden.'**
  String get noOtherSavegames;

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

  /// Snackbar-Fehlermeldung, wenn ein Spielstand nicht gespeichert werden konnte (V6)
  ///
  /// In de, this message translates to:
  /// **'Speichern fehlgeschlagen – Änderungen sind eventuell verloren.'**
  String get saveFailed;

  /// Titel des Dialogs, wenn Spielstand-Dateien nicht geladen werden konnten (V6)
  ///
  /// In de, this message translates to:
  /// **'Spielstand nicht ladbar'**
  String get storageLoadErrorTitle;

  /// Meldung mit den nicht ladbaren Spielstand-Dateien (V6)
  ///
  /// In de, this message translates to:
  /// **'Beschädigte Spielstand-Dateien:\n{files}'**
  String storageLoadErrorMessage(String files);

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

  /// Aktion: Lehrling zum Line Cook fortbilden
  ///
  /// In de, this message translates to:
  /// **'Zum Line Cook fortbilden'**
  String get promoteToLineCook;

  /// Meldung, wenn das Level für die Fortbildung zu niedrig ist
  ///
  /// In de, this message translates to:
  /// **'Fortbildung erst ab Level 5 möglich!'**
  String get promoteLevelRequired;

  /// Bestätigungsdialog der Fortbildung
  ///
  /// In de, this message translates to:
  /// **'{name} zum Line Cook fortbilden? Kosten: {cost} €'**
  String promoteConfirm(String name, int cost);

  /// Fehlermeldung, wenn das Budget für die Fortbildung nicht reicht
  ///
  /// In de, this message translates to:
  /// **'Budget reicht nicht für die Fortbildung!'**
  String get promoteNotEnoughBudget;

  /// Snackbar nach erfolgreicher Fortbildung
  ///
  /// In de, this message translates to:
  /// **'{name} ist jetzt ein Line Cook!'**
  String promoteSuccess(String name);

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

  /// Rangbezeichnung: Chef de partie
  ///
  /// In de, this message translates to:
  /// **'Chef de partie'**
  String get rankChefDePartie;

  /// Rangbezeichnung: Sous-chef
  ///
  /// In de, this message translates to:
  /// **'Sous-chef'**
  String get rankSousChef;

  /// Rangbezeichnung: Chef de cuisine
  ///
  /// In de, this message translates to:
  /// **'Chef de cuisine'**
  String get rankHeadChef;

  /// Bezeichnung der Küchenstation (Karrierepfade, V10)
  ///
  /// In de, this message translates to:
  /// **'Station'**
  String get station;

  /// Hinweis, solange keine Station gewählt wurde
  ///
  /// In de, this message translates to:
  /// **'Keine Station gewählt'**
  String get stationNone;

  /// Aktion: Küchenstation wählen
  ///
  /// In de, this message translates to:
  /// **'Station wählen'**
  String get stationChoose;

  /// Erläuterung der Stationswirkung
  ///
  /// In de, this message translates to:
  /// **'Die Station wirkt auf den Charakter selbst und als Aura auf Verbündete im Umkreis.'**
  String get stationChooseHint;

  /// Bestätigung eines kostenpflichtigen Stations-Wechsels
  ///
  /// In de, this message translates to:
  /// **'Station wechseln? Das kostet {cost} €.'**
  String stationSwitchConfirm(int cost);

  /// Meldung bei unzulässiger Stationswahl
  ///
  /// In de, this message translates to:
  /// **'Diese Station ist hier nicht wählbar (Basis-Station fehlt).'**
  String get stationNotAllowed;

  /// Untertitel einer Varianten-Station
  ///
  /// In de, this message translates to:
  /// **'Variante von {base}'**
  String stationVariantOf(String base);

  /// Aktion: Beförderung zum Chef de partie
  ///
  /// In de, this message translates to:
  /// **'Zum Chef de partie befördern'**
  String get promoteToChefDePartie;

  /// Meldung, wenn das Level für die Beförderung zu niedrig ist
  ///
  /// In de, this message translates to:
  /// **'Beförderung erst ab Level {level} möglich!'**
  String promoteLevelRequiredFor(int level);

  /// Generischer Bestätigungsdialog einer Beförderung
  ///
  /// In de, this message translates to:
  /// **'{name} zum {rank} befördern? Kosten: {cost} €'**
  String promoteConfirmRank(String name, String rank, int cost);

  /// Aktion: Beförderung zum Sous-chef
  ///
  /// In de, this message translates to:
  /// **'Zum Sous-chef befördern'**
  String get promoteToSousChef;

  /// Aktion: Beförderung zum Chef de cuisine
  ///
  /// In de, this message translates to:
  /// **'Zum Chef de cuisine befördern'**
  String get promoteToHeadChef;

  /// Rolle eines zugeteilten Chef de cuisine (V10 § 6)
  ///
  /// In de, this message translates to:
  /// **'Aktiv'**
  String get headChefRoleActive;

  /// Rolle eines nicht zugeteilten Chef de cuisine (V10 § 6)
  ///
  /// In de, this message translates to:
  /// **'Formell'**
  String get headChefRoleFormal;

  /// Aktion: Chef de cuisine dem Restaurant zuteilen
  ///
  /// In de, this message translates to:
  /// **'Zum aktiven Chef machen'**
  String get headChefAssign;

  /// Unikat-Invariante: nur ein aktiver Chef pro Restaurant
  ///
  /// In de, this message translates to:
  /// **'Es ist bereits ein aktiver Chef de cuisine zugeteilt.'**
  String get headChefAssignForbidden;

  /// Bestätigung der Zuteilung
  ///
  /// In de, this message translates to:
  /// **'{name} führt das Restaurant jetzt als aktiver Chef de cuisine.'**
  String headChefAssigned(String name);

  /// Meldung beim Nachrücken eines formellen Chefs
  ///
  /// In de, this message translates to:
  /// **'{name} rückt als aktiver Chef de cuisine nach.'**
  String headChefNachrueck(String name);

  /// Wochenlohn eines Charakters (V10, Phase 7)
  ///
  /// In de, this message translates to:
  /// **'Wochenlohn: {amount} €'**
  String weeklyWage(int amount);

  /// Abschnitt für Hilfs-/Service-Rollen (V10, Phase 6)
  ///
  /// In de, this message translates to:
  /// **'Hilfs- und Service-Rollen'**
  String get supportRoles;

  /// Rolle: Communard
  ///
  /// In de, this message translates to:
  /// **'Communard (Staff cook)'**
  String get supportRoleCommunard;

  /// Wirkung: Communard
  ///
  /// In de, this message translates to:
  /// **'Verbessert den Wochen-Refill der Kollegen.'**
  String get supportRoleEffectCommunard;

  /// Rolle: Tournant
  ///
  /// In de, this message translates to:
  /// **'Tournant (Roundsman)'**
  String get supportRoleTournant;

  /// Wirkung: Tournant
  ///
  /// In de, this message translates to:
  /// **'Senkt den Erschöpfungs-Malus der Nulltage.'**
  String get supportRoleEffectTournant;

  /// Rolle: Aboyeur
  ///
  /// In de, this message translates to:
  /// **'Aboyeur (Expediter)'**
  String get supportRoleAboyeur;

  /// Wirkung: Aboyeur
  ///
  /// In de, this message translates to:
  /// **'Verbessert den Bestellfluss (Einnahmen).'**
  String get supportRoleEffectAboyeur;

  /// Rolle: Plongeur
  ///
  /// In de, this message translates to:
  /// **'Plongeur (Dishwasher)'**
  String get supportRolePlongeur;

  /// Wirkung: Plongeur
  ///
  /// In de, this message translates to:
  /// **'Senkt die laufenden Betriebskosten.'**
  String get supportRoleEffectPlongeur;

  /// Rolle: Commis
  ///
  /// In de, this message translates to:
  /// **'Commis de débarrasseur (Busser)'**
  String get supportRoleCommis;

  /// Wirkung: Commis
  ///
  /// In de, this message translates to:
  /// **'Leicht positiver Attraktivitäts-Effekt.'**
  String get supportRoleEffectCommis;

  /// Rolle: Boucher
  ///
  /// In de, this message translates to:
  /// **'Boucher (Butcher)'**
  String get supportRoleBoucher;

  /// Wirkung: Boucher
  ///
  /// In de, this message translates to:
  /// **'Erhöht die Beute nach Gefechten.'**
  String get supportRoleEffectBoucher;

  /// Rolle: Garçon de cuisine
  ///
  /// In de, this message translates to:
  /// **'Garçon de cuisine (Kitchen boy)'**
  String get supportRoleGarcon;

  /// Wirkung: Garçon de cuisine
  ///
  /// In de, this message translates to:
  /// **'Kleiner Bonus auf Attraktivität und Zufriedenheit.'**
  String get supportRoleEffectGarcon;

  /// Abschnitt für Verwaltungs-/Marketing-Rollen (Option C)
  ///
  /// In de, this message translates to:
  /// **'Verwaltung & Marketing'**
  String get managementRoles;

  /// Rolle: Social Media Manager
  ///
  /// In de, this message translates to:
  /// **'Social Media Manager'**
  String get managementRoleSocialMediaManager;

  /// Wirkung: Social Media Manager
  ///
  /// In de, this message translates to:
  /// **'Erhöht das passive Einkommen.'**
  String get managementRoleEffectSocialMediaManager;

  /// Feature: PR-Kampagne (Social Media Manager)
  ///
  /// In de, this message translates to:
  /// **'PR-Kampagne'**
  String get managementFeaturePrCampaign;

  /// Wirkung: PR-Kampagne
  ///
  /// In de, this message translates to:
  /// **'Aktive Fertigkeit: befristeter XP-Boost für ein Teammitglied.'**
  String get managementFeaturePrCampaignEffect;

  /// Button: aktives Feature starten
  ///
  /// In de, this message translates to:
  /// **'Feature aktivieren'**
  String get managementFeatureActivate;

  /// Dialogtitel: Ziel des Features wählen
  ///
  /// In de, this message translates to:
  /// **'Kampagnen-Ziel wählen'**
  String get managementFeatureSelectTarget;

  /// Einmalkosten der Feature-Aktivierung
  ///
  /// In de, this message translates to:
  /// **'Aktivierung: {cost} €'**
  String managementFeatureCost(int cost);

  /// Kompetenz-Stufe des Feature-Trägers
  ///
  /// In de, this message translates to:
  /// **'Kompetenz {level}'**
  String managementFeatureCompetence(int level);

  /// Laufzeit der aktiven Feature-Phase
  ///
  /// In de, this message translates to:
  /// **'Aktiv bis {time}'**
  String managementFeatureActive(String time);

  /// Laufzeit der Nachteilphase
  ///
  /// In de, this message translates to:
  /// **'Nachwirkung bis {time}'**
  String managementFeatureAftermath(String time);

  /// Hinweis: kein geeignetes Kampagnen-Ziel
  ///
  /// In de, this message translates to:
  /// **'Kein einsatzfähiges Ziel verfügbar.'**
  String get managementFeatureNoTargets;

  /// Fehlermeldung: Feature konnte nicht aktiviert werden
  ///
  /// In de, this message translates to:
  /// **'Aktivierung nicht möglich.'**
  String get managementFeatureActivationFailed;

  /// Rolle: Chefsekretärin (11a E12)
  ///
  /// In de, this message translates to:
  /// **'Chefsekretärin'**
  String get managementRoleChefSecretary;

  /// Wirkung: Chefsekretärin
  ///
  /// In de, this message translates to:
  /// **'Senkt Mitarbeiter- und Erweiterungs-Anschaffungskosten.'**
  String get managementRoleEffectChefSecretary;

  /// Rolle: Rechtsanwalt (11a E12)
  ///
  /// In de, this message translates to:
  /// **'Rechtsanwalt'**
  String get managementRoleLawyer;

  /// Wirkung: Rechtsanwalt
  ///
  /// In de, this message translates to:
  /// **'Senkt erlittene Strafen.'**
  String get managementRoleEffectLawyer;

  /// Rolle: Buchhalter (11a E12)
  ///
  /// In de, this message translates to:
  /// **'Buchhalter'**
  String get managementRoleAccountant;

  /// Wirkung: Buchhalter
  ///
  /// In de, this message translates to:
  /// **'Senkt alle laufenden Kosten.'**
  String get managementRoleEffectAccountant;

  /// Feature: Sabotage (Chefsekretärin, 11a E14)
  ///
  /// In de, this message translates to:
  /// **'Sabotage'**
  String get managementFeatureSabotage;

  /// Wirkung: Sabotage
  ///
  /// In de, this message translates to:
  /// **'Aktive Fertigkeit: externe Kräfte sabotieren ein Rivalen-Restaurant.'**
  String get managementFeatureSabotageEffect;

  /// Feature: Winkelzug (Rechtsanwalt, 11a E15)
  ///
  /// In de, this message translates to:
  /// **'Winkelzug'**
  String get managementFeatureLegalTrick;

  /// Wirkung: Winkelzug
  ///
  /// In de, this message translates to:
  /// **'Aktive Fertigkeit: mildert eine eintreffende Strafe.'**
  String get managementFeatureLegalTrickEffect;

  /// Feature: Kreative Buchführung (Buchhalter, 11a E16)
  ///
  /// In de, this message translates to:
  /// **'Kreative Buchführung'**
  String get managementFeatureCreativeAccounting;

  /// Wirkung: Kreative Buchführung
  ///
  /// In de, this message translates to:
  /// **'Aktive Fertigkeit: negiert befristet alle laufenden Kosten; danach Burnout.'**
  String get managementFeatureCreativeAccountingEffect;

  /// Rolle: Oberkellner (V12)
  ///
  /// In de, this message translates to:
  /// **'Oberkellner'**
  String get managementRoleHeadWaiter;

  /// Wirkung: Oberkellner
  ///
  /// In de, this message translates to:
  /// **'Hebt Attraktivität und Kapazität.'**
  String get managementRoleEffectHeadWaiter;

  /// Rolle: Personalchef (V12)
  ///
  /// In de, this message translates to:
  /// **'Personalchef'**
  String get managementRolePersonnelManager;

  /// Wirkung: Personalchef
  ///
  /// In de, this message translates to:
  /// **'Hebt Kundenzufriedenheit und Kapazität.'**
  String get managementRoleEffectPersonnelManager;

  /// Rolle: Lagerist (V12)
  ///
  /// In de, this message translates to:
  /// **'Lagerist'**
  String get managementRoleStorekeeper;

  /// Wirkung: Lagerist
  ///
  /// In de, this message translates to:
  /// **'Hebt die Kapazität deutlich.'**
  String get managementRoleEffectStorekeeper;

  /// Rolle: Gewerkschaftschef (V12)
  ///
  /// In de, this message translates to:
  /// **'Gewerkschaftschef'**
  String get managementRoleUnionChief;

  /// Wirkung: Gewerkschaftschef
  ///
  /// In de, this message translates to:
  /// **'Erhöht die Mitarbeiterkosten, senkt dafür deren Erschöpfung.'**
  String get managementRoleEffectUnionChief;

  /// Feature: Rush Hour (Oberkellner, V12)
  ///
  /// In de, this message translates to:
  /// **'Rush Hour'**
  String get managementFeatureRushHour;

  /// Wirkung: Rush Hour
  ///
  /// In de, this message translates to:
  /// **'Aktive Fertigkeit: hebt befristet alle Eingangswerte; Mali entfallen, dafür Erschöpfung.'**
  String get managementFeatureRushHourEffect;

  /// Feature: Organisation ist alles (Personalchef, V12)
  ///
  /// In de, this message translates to:
  /// **'Organisation ist alles'**
  String get managementFeatureOrganisationIsEverything;

  /// Wirkung: Organisation ist alles
  ///
  /// In de, this message translates to:
  /// **'Aktive Fertigkeit: senkt befristet den Stabilitätsverlust – gegen Geld.'**
  String get managementFeatureOrganisationIsEverythingEffect;

  /// Feature: Lagertetris (Lagerist, V12)
  ///
  /// In de, this message translates to:
  /// **'Lagertetris'**
  String get managementFeatureStorageTetris;

  /// Wirkung: Lagertetris
  ///
  /// In de, this message translates to:
  /// **'Aktive Fertigkeit: vervielfacht befristet die Kapazität; alle Mali entfallen.'**
  String get managementFeatureStorageTetrisEffect;

  /// Feature: Alle Räder … (Gewerkschaftschef, V12)
  ///
  /// In de, this message translates to:
  /// **'Alle Räder …'**
  String get managementFeatureUnionWorkers;

  /// Wirkung: Alle Räder …
  ///
  /// In de, this message translates to:
  /// **'Aktive Fertigkeit: Sabotage-Mannschaft mit gemittelter Shadiness und Rerolls.'**
  String get managementFeatureUnionWorkersEffect;

  /// Rolle: Sicherheitschef (V13)
  ///
  /// In de, this message translates to:
  /// **'Sicherheitschef'**
  String get managementRoleSecurityChief;

  /// Wirkung: Sicherheitschef
  ///
  /// In de, this message translates to:
  /// **'Entdeckt Sabotageversuche gegen das Restaurant.'**
  String get managementRoleEffectSecurityChief;

  /// Feature: Rache ist Blutwurst (Sicherheitschef, V13)
  ///
  /// In de, this message translates to:
  /// **'Rache ist Blutwurst'**
  String get managementFeatureCounterSabotage;

  /// Wirkung: Rache ist Blutwurst
  ///
  /// In de, this message translates to:
  /// **'Aktive Fertigkeit: schlägt gegen einen im Fenster entdeckten Angreifer zurück.'**
  String get managementFeatureCounterSabotageEffect;

  /// Scharf geschalteter Gegenschlag (Auflösung im Wochentick)
  ///
  /// In de, this message translates to:
  /// **'Gegenschlag bereit bis {time}'**
  String managementCounterSabotagePending(String time);

  /// Dialogtitel: Mannschaft für 'Alle Räder …' wählen
  ///
  /// In de, this message translates to:
  /// **'Schlagmannschaft wählen'**
  String get managementFeatureSelectTeam;

  /// Laufende Tageskosten eines Features
  ///
  /// In de, this message translates to:
  /// **'Laufend: {cost} € / Tag'**
  String managementFeatureDailyCost(int cost);

  /// Dialogtitel: Rivale für die Sabotage wählen
  ///
  /// In de, this message translates to:
  /// **'Ziel der Sabotage wählen'**
  String get managementSabotageSelectTarget;

  /// Erfolgswahrscheinlichkeit einer Sabotage
  ///
  /// In de, this message translates to:
  /// **'Erfolgschance {percent} %'**
  String managementSabotageSuccessChance(int percent);

  /// Hinweis: keine Rivalen im Stadtteil
  ///
  /// In de, this message translates to:
  /// **'Kein Rivale im Stadtteil verfügbar.'**
  String get managementSabotageNoRivals;

  /// Laufende Sabotage (Auflösung im Wochentick)
  ///
  /// In de, this message translates to:
  /// **'Sabotage läuft bis {time}'**
  String managementSabotagePending(String time);

  /// Wirkungsfenster einer erfolgreichen Sabotage
  ///
  /// In de, this message translates to:
  /// **'Sabotage wirkt bis {time}'**
  String managementSabotageEffect(String time);

  /// Abschnitt: Rivalen-Restaurants (Kapitel 13)
  ///
  /// In de, this message translates to:
  /// **'Konkurrenz im Stadtteil'**
  String get rivalsSection;

  /// Anzahl der Rivalen im Stadtteil
  ///
  /// In de, this message translates to:
  /// **'{count} Rivalen'**
  String rivalCount(int count);

  /// Status: Rivale ist sabotiert
  ///
  /// In de, this message translates to:
  /// **'sabotiert'**
  String get rivalSabotaged;

  /// Aktion: Personal in ein eigenes Restaurant verschieben (V10)
  ///
  /// In de, this message translates to:
  /// **'Verschieben nach …'**
  String get transferTo;

  /// Titel der Zielauswahl beim Personal-Transfer
  ///
  /// In de, this message translates to:
  /// **'Ziel-Restaurant wählen'**
  String get transferSelectTitle;

  /// Bestätigung des Personal-Transfers
  ///
  /// In de, this message translates to:
  /// **'{name} nach {target} verschieben? Kosten: {cost} € – das Ziel-Restaurant zahlt.'**
  String transferConfirm(String name, String target, int cost);

  /// Erfolgsmeldung des Personal-Transfers
  ///
  /// In de, this message translates to:
  /// **'{name} wechselt nach {target}.'**
  String transferSuccess(String name, String target);

  /// Fehlermeldung des Personal-Transfers
  ///
  /// In de, this message translates to:
  /// **'Transfer nicht möglich (Ziel aufgelöst oder Budget zu gering).'**
  String get transferFailed;

  /// Hinweis, wenn es kein Ziel-Restaurant gibt
  ///
  /// In de, this message translates to:
  /// **'Kein anderes Restaurant verfügbar.'**
  String get transferNoTargets;

  /// Stationsname (FR): Saucier
  ///
  /// In de, this message translates to:
  /// **'Saucier'**
  String get stationSaucier;

  /// Stationsname (FR): Poissonnier
  ///
  /// In de, this message translates to:
  /// **'Poissonnier'**
  String get stationPoissonnier;

  /// Stationsname (FR): Rôtisseur
  ///
  /// In de, this message translates to:
  /// **'Rôtisseur'**
  String get stationRotisseur;

  /// Stationsname (FR): Grillardin
  ///
  /// In de, this message translates to:
  /// **'Grillardin'**
  String get stationGrillardin;

  /// Stationsname (FR): Friturier
  ///
  /// In de, this message translates to:
  /// **'Friturier'**
  String get stationFriturier;

  /// Stationsname (FR): Entremétier
  ///
  /// In de, this message translates to:
  /// **'Entremétier'**
  String get stationEntremetier;

  /// Stationsname (FR): Potager
  ///
  /// In de, this message translates to:
  /// **'Potager'**
  String get stationPotager;

  /// Stationsname (FR): Légumier
  ///
  /// In de, this message translates to:
  /// **'Légumier'**
  String get stationLegumier;

  /// Stationsname (FR): Garde manger
  ///
  /// In de, this message translates to:
  /// **'Garde manger'**
  String get stationGardeManger;

  /// Stationsname (FR): Charcutier
  ///
  /// In de, this message translates to:
  /// **'Charcutier'**
  String get stationCharcutier;

  /// Stationsname (FR): Pâtissier
  ///
  /// In de, this message translates to:
  /// **'Pâtissier'**
  String get stationPatissier;

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

  /// Status: Charakter ist bereit (keine Verletzung)
  ///
  /// In de, this message translates to:
  /// **'Bereit'**
  String get statusReady;

  /// Status: Charakter ist benommen
  ///
  /// In de, this message translates to:
  /// **'Benommen'**
  String get statusReeling;

  /// Status: Charakter ist verletzt
  ///
  /// In de, this message translates to:
  /// **'Verletzt'**
  String get statusHurt;

  /// Status: Charakter ist verängstigt
  ///
  /// In de, this message translates to:
  /// **'Verängstigt'**
  String get statusAfraid;

  /// Status: Charakter ist schwer verletzt
  ///
  /// In de, this message translates to:
  /// **'Schwer verletzt'**
  String get statusInjured;

  /// Status: Charakter liegt im Sterben
  ///
  /// In de, this message translates to:
  /// **'Sterbend'**
  String get statusDying;

  /// Status: Charakter ist tot
  ///
  /// In de, this message translates to:
  /// **'Tot'**
  String get statusDead;

  /// Status: Charakter wurde zerfetzt (übermäßiger Schaden)
  ///
  /// In de, this message translates to:
  /// **'Zerfetzt'**
  String get statusOverkilled;

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

  /// Countdown bis zum nächsten Wochentick
  ///
  /// In de, this message translates to:
  /// **'Nächste Abbuchung in {days} Tagen'**
  String nextBillingCountdown(int days);

  /// Warnung nahe der Negativgrenze
  ///
  /// In de, this message translates to:
  /// **'Achtung: Das Budget nähert sich der Negativgrenze!'**
  String get budgetWarning;

  /// Anzeige Kunden pro Woche
  ///
  /// In de, this message translates to:
  /// **'{count} Kunden/Woche'**
  String customersPerWeekLabel(int count);

  /// Anzeige passives Einkommen pro Woche
  ///
  /// In de, this message translates to:
  /// **'Passiv: {income} €/Woche'**
  String passiveIncomeLabel(int income);

  /// Anzeige Teamarzt-Kosten pro Woche
  ///
  /// In de, this message translates to:
  /// **'Ärzte: {cost} €/Woche'**
  String medicCostsLabel(int cost);

  /// Summe der wöchentlichen Arztkosten
  ///
  /// In de, this message translates to:
  /// **'Gesamtwochenlast: {cost} €'**
  String weeklyLoadTotal(int cost);

  /// Titel des Permadeath-Dialogs
  ///
  /// In de, this message translates to:
  /// **'Bankrott!'**
  String get bankruptDialogTitle;

  /// Text des Permadeath-Dialogs
  ///
  /// In de, this message translates to:
  /// **'Die Investoren lösen das Restaurant auf. Du startest mit einem neuen Restaurant.'**
  String get bankruptDialogMessage;

  /// Button für den Neustart nach Bankrott
  ///
  /// In de, this message translates to:
  /// **'Neues Restaurant starten'**
  String get bankruptNewRestaurant;

  /// Beschriftung der Küchenauswahl
  ///
  /// In de, this message translates to:
  /// **'Küche'**
  String get cuisineSection;

  /// Anzeige der Küche im Header
  ///
  /// In de, this message translates to:
  /// **'Küche: {cuisine}'**
  String cuisineLabel(String cuisine);

  /// Küche: Italienisch
  ///
  /// In de, this message translates to:
  /// **'Italienisch'**
  String get cuisineItalian;

  /// Küche: Japanisch
  ///
  /// In de, this message translates to:
  /// **'Japanisch'**
  String get cuisineJapanese;

  /// Küche: Chinesisch
  ///
  /// In de, this message translates to:
  /// **'Chinesisch'**
  String get cuisineChinese;

  /// Küche: Deutsch
  ///
  /// In de, this message translates to:
  /// **'Deutsch'**
  String get cuisineGerman;

  /// Küche: Kanadisch
  ///
  /// In de, this message translates to:
  /// **'Kanadisch'**
  String get cuisineCanadian;

  /// Küche: Mexikanisch
  ///
  /// In de, this message translates to:
  /// **'Mexikanisch'**
  String get cuisineMexican;

  /// Aktion: Küche wechseln
  ///
  /// In de, this message translates to:
  /// **'Küche wechseln (Rebranding)'**
  String get rebrandCuisine;

  /// Titel des Rebranding-Dialogs
  ///
  /// In de, this message translates to:
  /// **'Küche wechseln?'**
  String get rebrandDialogTitle;

  /// Text des Rebranding-Dialogs
  ///
  /// In de, this message translates to:
  /// **'Der Wechsel kostet {cost} € und zieht kurzfristig weniger Gäste an.'**
  String rebrandDialogMessage(int cost);

  /// Bestätigen-Button für Rebranding
  ///
  /// In de, this message translates to:
  /// **'Wechseln'**
  String get rebrandConfirm;

  /// Snackbar nach erfolgreichem Rebranding
  ///
  /// In de, this message translates to:
  /// **'Küche gewechselt!'**
  String get rebrandSuccess;

  /// Fehlermeldung Rebranding
  ///
  /// In de, this message translates to:
  /// **'Budget reicht nicht für das Rebranding!'**
  String get rebrandNotEnoughBudget;

  /// Abschnittstitel Erweiterungen
  ///
  /// In de, this message translates to:
  /// **'Restauranterweiterungen'**
  String get upgradesSection;

  /// Erweiterung: Mehr Tische
  ///
  /// In de, this message translates to:
  /// **'Mehr Tische'**
  String get upgradeTables;

  /// Erweiterung: Größere Küche
  ///
  /// In de, this message translates to:
  /// **'Größere Küche'**
  String get upgradeKitchen;

  /// Erweiterung: Werbeplakate
  ///
  /// In de, this message translates to:
  /// **'Werbeplakate'**
  String get upgradeSignage;

  /// Erweiterung: Dekorationen
  ///
  /// In de, this message translates to:
  /// **'Dekorationen'**
  String get upgradeDecoration;

  /// Erweiterung: Musikautomat
  ///
  /// In de, this message translates to:
  /// **'Musikautomat'**
  String get upgradeJukebox;

  /// Ausbaustufe einer Erweiterung
  ///
  /// In de, this message translates to:
  /// **'Stufe {level}/{max}'**
  String upgradeLevel(int level, int max);

  /// Anschaffungskosten der nächsten Stufe
  ///
  /// In de, this message translates to:
  /// **'Ausbau: {cost} €'**
  String upgradeBuyCost(int cost);

  /// Wöchentlicher Unterhalt der Erweiterung
  ///
  /// In de, this message translates to:
  /// **'Unterhalt: {cost} €/Woche'**
  String upgradeUpkeepCost(int cost);

  /// Button: Erweiterung ausbauen
  ///
  /// In de, this message translates to:
  /// **'Ausbauen'**
  String get upgradeBuy;

  /// Button: Erweiterung zurückbauen
  ///
  /// In de, this message translates to:
  /// **'Zurückbauen'**
  String get upgradeDowngrade;

  /// Button: Erweiterung verkaufen
  ///
  /// In de, this message translates to:
  /// **'Verkaufen'**
  String get upgradeSell;

  /// Maximalstufe erreicht
  ///
  /// In de, this message translates to:
  /// **'Maximalstufe'**
  String get upgradeMaxReached;

  /// Fehlermeldung Ausbau
  ///
  /// In de, this message translates to:
  /// **'Budget reicht nicht für den Ausbau!'**
  String get upgradeNotEnoughBudget;

  /// Snackbar nach Verkauf
  ///
  /// In de, this message translates to:
  /// **'Verkauft: +{amount} €'**
  String upgradeSold(int amount);

  /// Reiter: Aktives Personal
  ///
  /// In de, this message translates to:
  /// **'Aktives Personal'**
  String get tabPersonnel;

  /// Reiter: Teamarzt
  ///
  /// In de, this message translates to:
  /// **'Teamarzt'**
  String get tabMedics;

  /// Reiter: Erweiterungen
  ///
  /// In de, this message translates to:
  /// **'Erweiterungen'**
  String get tabUpgrades;

  /// Reiter: Karte & Gefecht
  ///
  /// In de, this message translates to:
  /// **'Karte & Gefecht'**
  String get tabBattle;

  /// Anzeige des aktiven Rebranding-Malus
  ///
  /// In de, this message translates to:
  /// **'Rebranding aktiv: Attraktivität −1 (noch {days} Tage)'**
  String rebrandingPenaltyActive(int days);

  /// Countdown bis zur vollständigen Heilung (V3)
  ///
  /// In de, this message translates to:
  /// **'Heilung fertig in ca. {hours} h {minutes} min'**
  String healCountdown(int hours, int minutes);

  /// Countdown bis zum Rückfall der Notfall-Spritze (V3)
  ///
  /// In de, this message translates to:
  /// **'Rückfall in ca. {hours} h {minutes} min'**
  String shotCountdown(int hours, int minutes);

  /// Zusammenfassung des Echtzeit-Catch-up (V8/§ 6)
  ///
  /// In de, this message translates to:
  /// **'{weeks, plural, =1{1 Woche abgerechnet} other{{weeks} Wochen abgerechnet}}: Einkommen +{income} €, Arzt −{medicCosts} €, Unterhalt −{upkeep} €, Zinsen −{interest} €'**
  String catchUpSummary(
    int weeks,
    int income,
    int medicCosts,
    int upkeep,
    int interest,
  );

  /// Anteilige Resttage der Tagesabgrenzung (V8/§ 6)
  ///
  /// In de, this message translates to:
  /// **'{days, plural, =1{1 Resttag} other{{days} Resttage}} Einkommen: +{income} €'**
  String catchUpLeftover(int days, int income);

  /// Unentdeckte Rivalen-Sabotage schöpft Blockeinkommen ab (V13, Kapitel 13)
  ///
  /// In de, this message translates to:
  /// **'Rivalen-Sabotage: Einkommen −{loss} €'**
  String catchUpRivalSabotageLoss(int loss);

  /// Charakter ist vollständig geheilt (V3)
  ///
  /// In de, this message translates to:
  /// **'Voll einsatzbereit'**
  String get healingComplete;

  /// Enneagramm-Profil des Charakters (V9)
  ///
  /// In de, this message translates to:
  /// **'Persönlichkeit: {name}'**
  String personalityLabel(String name);

  /// Ressourcenstände des Charakters (V9 § 2)
  ///
  /// In de, this message translates to:
  /// **'Vitalität {vitality}/100 · Moral {morale}/100'**
  String resourcesLine(int vitality, int morale);

  /// Laufender Stress-Override (V9 § 6)
  ///
  /// In de, this message translates to:
  /// **'Unter Stress – Wechsel bis {time}'**
  String stressCountdown(String time);

  /// Laufender Ruhe-Override (V9 § 6)
  ///
  /// In de, this message translates to:
  /// **'In Ruhe – Wechsel bis {time}'**
  String ruheCountdown(String time);

  /// Kumulativer Erschöpfungs-Malus (V9 § 6)
  ///
  /// In de, this message translates to:
  /// **'Erschöpft: −{malus} % auf alle Würfe'**
  String resourceZeroMalus(int malus);

  /// Persönlichkeits-Scores des Teamarztes (V9 § 4)
  ///
  /// In de, this message translates to:
  /// **'Hilfsbereitschaft {helpfulness} · Behandlungsqualität {treatment}'**
  String medicScores(int helpfulness, int treatment);
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
