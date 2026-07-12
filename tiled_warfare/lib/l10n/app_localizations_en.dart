// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Tiled Warfare';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get create => 'Create';

  @override
  String get edit => 'Edit';

  @override
  String get newProfile => 'New Profile';

  @override
  String get renameProfile => 'Rename Profile';

  @override
  String get deleteProfile => 'Delete Profile';

  @override
  String deleteProfileConfirm(String name) {
    return 'Are you sure you want to delete profile \"$name\"?\nAll associated data will be permanently removed.';
  }

  @override
  String get profileName => 'Profile Name';

  @override
  String get playerNameHint => 'Name of the player';

  @override
  String get pleaseEnterName => 'Please enter a name.';

  @override
  String get newRestaurant => 'New Restaurant';

  @override
  String get renameRestaurant => 'Change Restaurant Name';

  @override
  String get deleteRestaurant => 'Delete Restaurant';

  @override
  String deleteRestaurantConfirm(String name) {
    return 'Are you sure you want to delete restaurant \"$name\"?';
  }

  @override
  String get restaurantName => 'Restaurant Name';

  @override
  String get restaurantNameHint => 'Name of the restaurant';

  @override
  String get newNameHint => 'Enter new name';

  @override
  String get profileSection => 'Profiles';

  @override
  String get newProfileTooltip => 'New Profile';

  @override
  String get renameProfileTooltip => 'Rename Profile';

  @override
  String get deleteProfileTooltip => 'Delete Profile';

  @override
  String get noProfilesYet => 'No profiles yet.\nCreate a new profile!';

  @override
  String profileSubtitle(int id, String date, int count) {
    return 'ID: $id\nCreated: $date\nRestaurants: $count';
  }

  @override
  String get profileImageError => 'Error loading profile image.';

  @override
  String get restaurantSection => 'Restaurants';

  @override
  String get newRestaurantTooltip => 'New Restaurant';

  @override
  String get deleteRestaurantTooltip => 'Delete Restaurant';

  @override
  String get selectProfileFirst => 'Select a profile first.';

  @override
  String get noRestaurantsYet =>
      'No restaurants yet.\nCreate a new restaurant!';

  @override
  String loginAs(String name) {
    return 'Log in as $name';
  }

  @override
  String get selectProfilePrompt => 'Please select a profile';

  @override
  String themeToggle(String mode) {
    return 'Toggle theme ($mode)';
  }

  @override
  String get personnelManagement => 'Personnel Management';

  @override
  String get regeneratePool => 'Regenerate Pool';

  @override
  String hiredPersonnel(int count) {
    return 'Hired ($count)';
  }

  @override
  String availableCandidates(int count) {
    return 'Available Candidates ($count)';
  }

  @override
  String get noCandidatesAvailable => 'No candidates available.';

  @override
  String get generateNewPool => 'Generate New Pool';

  @override
  String get qualityLow => 'Low';

  @override
  String get qualityMedium => 'Medium';

  @override
  String get qualityHigh => 'High';

  @override
  String costPerWeek(int cost) {
    return '$cost € / week';
  }

  @override
  String get fire => 'Fire';

  @override
  String get hire => 'Hire';

  @override
  String get restaurant => 'Restaurant';

  @override
  String get player => 'Player';

  @override
  String budgetLabel(int budget) {
    return '$budget €';
  }

  @override
  String personnelCount(int count) {
    return 'Personnel ($count)';
  }

  @override
  String get noPersonnelYet => 'No personnel hired yet.\nHire an apprentice!';

  @override
  String get hireNewPersonnel => 'Hire New Personnel';

  @override
  String get notEnoughBudget => 'Not enough budget to hire!';

  @override
  String get availableMaps => 'Available Maps';

  @override
  String mapLoadError(String error) {
    return 'Error loading maps:\n$error';
  }

  @override
  String get noMapsFound => 'No maps found.';

  @override
  String get startBattle => 'Start Battle';

  @override
  String get restaurantLogoError => 'Error loading restaurant logo.';

  @override
  String get changeProfileImage => 'Change profile image';

  @override
  String get managePersonnel => 'Manage personnel (hire/fire)';

  @override
  String get characterDetail => 'Character Details';

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
    return 'HP: $value';
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
    return 'Matches: ${wins}W / ${losses}L / ${draws}D';
  }

  @override
  String get noMatchData => 'No match data yet';

  @override
  String get matchHistory => 'Match History';

  @override
  String get noMatchHistory => 'No match history available.';

  @override
  String get tableDate => 'Date';

  @override
  String get tableOpponent => 'Opponent';

  @override
  String get tableResult => 'Result';

  @override
  String get tableKD => 'K/D';

  @override
  String get tableEvents => 'Events';

  @override
  String get teamMedic => 'Team Medic:';

  @override
  String get treat => 'Treat';

  @override
  String treatmentSuccess(String name) {
    return '$name has been treated.';
  }

  @override
  String get treatmentFailed => 'Treatment failed.';

  @override
  String get emergencyShot => 'Emergency Shot';

  @override
  String emergencyShotSuccess(String name) {
    return '$name received an emergency shot.';
  }

  @override
  String get emergencyShotFailed => 'Emergency shot failed.';

  @override
  String xpLabel(int current, int threshold) {
    return 'XP: $current / $threshold';
  }

  @override
  String get levelUpPossible => 'Level up possible!';

  @override
  String get info => 'Info';

  @override
  String get close => 'Close';

  @override
  String get melee => 'Melee';

  @override
  String get ranged => 'Ranged';

  @override
  String get apprenticeLabel => 'Apprentice';

  @override
  String get fallenLabel => 'Fallen';

  @override
  String get medicAssignTooltip => 'Assign team medic';

  @override
  String characterInfo(
    int attack,
    int defense,
    int movement,
    int damage,
    int range,
    int hp,
  ) {
    return 'ATK: $attack | DEF: $defense | MOV: $movement | DMG: $damage | RNG: $range | HP: $hp';
  }
}
