// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Tiled Warfare';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get delete => 'Löschen';

  @override
  String get save => 'Speichern';

  @override
  String get create => 'Erstellen';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get newProfile => 'Neues Profil';

  @override
  String get renameProfile => 'Profil umbenennen';

  @override
  String get deleteProfile => 'Profil löschen';

  @override
  String deleteProfileConfirm(String name) {
    return 'Soll das Profil \"$name\" wirklich gelöscht werden?\nAlle zugehörigen Daten werden unwiderruflich entfernt.';
  }

  @override
  String get profileName => 'Profilname';

  @override
  String get playerNameHint => 'Name des Spielers';

  @override
  String get pleaseEnterName => 'Bitte gib einen Namen ein.';

  @override
  String get newRestaurant => 'Neues Restaurant';

  @override
  String get renameRestaurant => 'Restaurantnamen ändern';

  @override
  String get deleteRestaurant => 'Restaurant löschen';

  @override
  String deleteRestaurantConfirm(String name) {
    return 'Soll das Restaurant \"$name\" wirklich gelöscht werden?';
  }

  @override
  String get restaurantName => 'Restaurantname';

  @override
  String get restaurantNameHint => 'Name des Restaurants';

  @override
  String get newNameHint => 'Neuen Namen eingeben';

  @override
  String get districtSection => 'Stadtteile';

  @override
  String districtLabel(String district) {
    return 'Stadtteil: $district';
  }

  @override
  String get foundRestaurant => 'Neues Restaurant gründen';

  @override
  String get dissolved => 'Aufgelöst';

  @override
  String get switchRestaurant => 'Spielstand wechseln';

  @override
  String districtLoadError(String error) {
    return 'Stadtteile konnten nicht geladen werden:\n$error';
  }

  @override
  String districtOccupied(String district) {
    return 'In $district gibt es bereits ein Restaurant.';
  }

  @override
  String get noOtherSavegames => 'Keine weiteren Spielstände vorhanden.';

  @override
  String get profileSection => 'Profile';

  @override
  String get newProfileTooltip => 'Neues Profil';

  @override
  String get renameProfileTooltip => 'Profil umbenennen';

  @override
  String get deleteProfileTooltip => 'Profil löschen';

  @override
  String get noProfilesYet =>
      'Noch keine Profile vorhanden.\nErstelle ein neues Profil!';

  @override
  String profileSubtitle(int id, String date, int count) {
    return 'ID: $id\nErstellt: $date\nRestaurants: $count';
  }

  @override
  String get profileImageError => 'Fehler beim Laden des Profilbildes.';

  @override
  String get restaurantSection => 'Restaurants';

  @override
  String get newRestaurantTooltip => 'Neues Restaurant';

  @override
  String get deleteRestaurantTooltip => 'Restaurant löschen';

  @override
  String get selectProfileFirst => 'Wähle zuerst ein Profil aus.';

  @override
  String get noRestaurantsYet =>
      'Noch keine Restaurants vorhanden.\nErstelle ein neues Restaurant!';

  @override
  String loginAs(String name) {
    return 'Einloggen als $name';
  }

  @override
  String get selectProfilePrompt => 'Bitte Profil auswählen';

  @override
  String themeToggle(String mode) {
    return 'Theme wechseln ($mode)';
  }

  @override
  String get personnelManagement => 'Personalverwaltung';

  @override
  String get regeneratePool => 'Pool neu generieren';

  @override
  String hiredPersonnel(int count) {
    return 'Angestellte ($count)';
  }

  @override
  String availableCandidates(int count) {
    return 'Verfügbare Kandidaten ($count)';
  }

  @override
  String get noCandidatesAvailable => 'Keine Kandidaten verfügbar.';

  @override
  String get generateNewPool => 'Neuen Pool generieren';

  @override
  String get qualityLow => 'Niedrig';

  @override
  String get qualityMedium => 'Mittel';

  @override
  String get qualityHigh => 'Hoch';

  @override
  String costPerWeek(int cost) {
    return '$cost € / Woche';
  }

  @override
  String get fire => 'Entlassen';

  @override
  String get hire => 'Anstellen';

  @override
  String get restaurant => 'Restaurant';

  @override
  String get player => 'Spieler';

  @override
  String budgetLabel(int budget) {
    return '$budget €';
  }

  @override
  String personnelCount(int count) {
    return 'Personal ($count)';
  }

  @override
  String get noPersonnelYet =>
      'Noch kein Personal eingestellt.\nHeuere einen Lehrling an!';

  @override
  String get hireNewPersonnel => 'Neues Personal anheuern';

  @override
  String get notEnoughBudget => 'Budget reicht nicht zum Anheuern!';

  @override
  String get availableMaps => 'Verfügbare Karten';

  @override
  String mapLoadError(String error) {
    return 'Fehler beim Laden der Karten:\n$error';
  }

  @override
  String get noMapsFound => 'Keine Karten gefunden.';

  @override
  String get startBattle => 'Gefecht starten';

  @override
  String get restaurantLogoError => 'Fehler beim Laden des Restaurantlogos.';

  @override
  String get changeProfileImage => 'Profilbild ändern';

  @override
  String get managePersonnel => 'Personal verwalten (anheuern/entlassen)';

  @override
  String get characterDetail => 'Charakterdetails';

  @override
  String get rankLineCook => 'Line Cook';

  @override
  String get rankApprentice => 'Apprentice';

  @override
  String level(int value) {
    return 'Level $value';
  }

  @override
  String hitPoints(int value) {
    return 'LP: $value';
  }

  @override
  String statsLine(
    int attack,
    int defense,
    int movement,
    int damage,
    int range,
  ) {
    return '⚔️ $attack  🛡️ $defense  🏃 $movement  💥 $damage  🎯 $range';
  }

  @override
  String kdRatio(String ratio) {
    return 'K/D: $ratio';
  }

  @override
  String matchStats(int wins, int losses, int draws) {
    return 'Matches: ${wins}S / ${losses}N / ${draws}U';
  }

  @override
  String get noMatchData => 'Noch keine Match-Daten';

  @override
  String get matchHistory => 'Match-Historie';

  @override
  String get noMatchHistory => 'Keine Match-Historie vorhanden.';

  @override
  String get tableDate => 'Datum';

  @override
  String get tableOpponent => 'Gegner';

  @override
  String get tableResult => 'Ergebnis';

  @override
  String get tableKD => 'K/D';

  @override
  String get tableEvents => 'Ereignisse';

  @override
  String get teamMedic => 'Teamarzt:';

  @override
  String get treat => 'Behandeln';

  @override
  String treatmentSuccess(String name) {
    return '$name wurde behandelt.';
  }

  @override
  String get treatmentFailed => 'Behandlung fehlgeschlagen.';

  @override
  String get emergencyShot => 'Notfall-Spritze';

  @override
  String emergencyShotSuccess(String name) {
    return '$name wurde eine Notfall-Spritze verabreicht.';
  }

  @override
  String get emergencyShotFailed => 'Notfall-Spritze fehlgeschlagen.';

  @override
  String xpLabel(int current, int threshold) {
    return 'XP: $current / $threshold';
  }

  @override
  String get levelUpPossible => 'Level-Aufstieg möglich!';

  @override
  String get info => 'Info';

  @override
  String get close => 'Schließen';

  @override
  String get melee => 'Nahkampf';

  @override
  String get ranged => 'Fernkampf';

  @override
  String get apprenticeLabel => 'Apprentice';

  @override
  String get fallenLabel => 'Ausgefallen';

  @override
  String get statusReady => 'Bereit';

  @override
  String get statusReeling => 'Benommen';

  @override
  String get statusHurt => 'Verletzt';

  @override
  String get statusAfraid => 'Verängstigt';

  @override
  String get statusInjured => 'Schwer verletzt';

  @override
  String get statusDying => 'Sterbend';

  @override
  String get statusDead => 'Tot';

  @override
  String get statusOverkilled => 'Zerfetzt';

  @override
  String get medicAssignTooltip => 'Teamarzt einsetzen';

  @override
  String characterInfo(
    int attack,
    int defense,
    int movement,
    int damage,
    int range,
    int hp,
  ) {
    return 'AW: $attack | VW: $defense | BW: $movement | SW: $damage | RW: $range | LP: $hp';
  }

  @override
  String nextBillingCountdown(int days) {
    return 'Nächste Abbuchung in $days Tagen';
  }

  @override
  String get budgetWarning =>
      'Achtung: Das Budget nähert sich der Negativgrenze!';

  @override
  String customersPerWeekLabel(int count) {
    return '$count Kunden/Woche';
  }

  @override
  String passiveIncomeLabel(int income) {
    return 'Passiv: $income €/Woche';
  }

  @override
  String medicCostsLabel(int cost) {
    return 'Ärzte: $cost €/Woche';
  }

  @override
  String weeklyLoadTotal(int cost) {
    return 'Gesamtwochenlast: $cost €';
  }

  @override
  String get bankruptDialogTitle => 'Bankrott!';

  @override
  String get bankruptDialogMessage =>
      'Die Investoren lösen das Restaurant auf. Du startest mit einem neuen Restaurant.';

  @override
  String get bankruptNewRestaurant => 'Neues Restaurant starten';

  @override
  String get cuisineSection => 'Küche';

  @override
  String cuisineLabel(String cuisine) {
    return 'Küche: $cuisine';
  }

  @override
  String get cuisineItalian => 'Italienisch';

  @override
  String get cuisineJapanese => 'Japanisch';

  @override
  String get cuisineChinese => 'Chinesisch';

  @override
  String get cuisineGerman => 'Deutsch';

  @override
  String get cuisineCanadian => 'Kanadisch';

  @override
  String get cuisineMexican => 'Mexikanisch';

  @override
  String get rebrandCuisine => 'Küche wechseln (Rebranding)';

  @override
  String get rebrandDialogTitle => 'Küche wechseln?';

  @override
  String rebrandDialogMessage(int cost) {
    return 'Der Wechsel kostet $cost € und zieht kurzfristig weniger Gäste an.';
  }

  @override
  String get rebrandConfirm => 'Wechseln';

  @override
  String get rebrandSuccess => 'Küche gewechselt!';

  @override
  String get rebrandNotEnoughBudget =>
      'Budget reicht nicht für das Rebranding!';

  @override
  String get upgradesSection => 'Restauranterweiterungen';

  @override
  String get upgradeTables => 'Mehr Tische';

  @override
  String get upgradeKitchen => 'Größere Küche';

  @override
  String get upgradeSignage => 'Werbeplakate';

  @override
  String get upgradeDecoration => 'Dekorationen';

  @override
  String get upgradeJukebox => 'Musikautomat';

  @override
  String upgradeLevel(int level, int max) {
    return 'Stufe $level/$max';
  }

  @override
  String upgradeBuyCost(int cost) {
    return 'Ausbau: $cost €';
  }

  @override
  String upgradeUpkeepCost(int cost) {
    return 'Unterhalt: $cost €/Woche';
  }

  @override
  String get upgradeBuy => 'Ausbauen';

  @override
  String get upgradeDowngrade => 'Zurückbauen';

  @override
  String get upgradeSell => 'Verkaufen';

  @override
  String get upgradeMaxReached => 'Maximalstufe';

  @override
  String get upgradeNotEnoughBudget => 'Budget reicht nicht für den Ausbau!';

  @override
  String upgradeSold(int amount) {
    return 'Verkauft: +$amount €';
  }

  @override
  String get tabPersonnel => 'Aktives Personal';

  @override
  String get tabMedics => 'Teamarzt';

  @override
  String get tabUpgrades => 'Erweiterungen';

  @override
  String get tabBattle => 'Karte & Gefecht';

  @override
  String rebrandingPenaltyActive(int days) {
    return 'Rebranding aktiv: Attraktivität −1 (noch $days Tage)';
  }

  @override
  String healCountdown(int hours, int minutes) {
    return 'Heilung fertig in ca. $hours h $minutes min';
  }

  @override
  String shotCountdown(int hours, int minutes) {
    return 'Rückfall in ca. $hours h $minutes min';
  }

  @override
  String get healingComplete => 'Voll einsatzbereit';
}
