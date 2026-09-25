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
  String get districtSection => 'Districts';

  @override
  String districtLabel(String district) {
    return 'District: $district';
  }

  @override
  String get foundRestaurant => 'Found new restaurant';

  @override
  String get dissolved => 'Dissolved';

  @override
  String get switchRestaurant => 'Switch save game';

  @override
  String districtLoadError(String error) {
    return 'Districts could not be loaded:\n$error';
  }

  @override
  String districtOccupied(String district) {
    return 'There is already a restaurant in $district.';
  }

  @override
  String get noOtherSavegames => 'No other save games available.';

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
  String get saveFailed => 'Saving failed – changes may be lost.';

  @override
  String get storageLoadErrorTitle => 'Savegame not loadable';

  @override
  String storageLoadErrorMessage(String files) {
    return 'Corrupted savegame files:\n$files';
  }

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
  String get promoteToLineCook => 'Promote to Line Cook';

  @override
  String get promoteLevelRequired => 'Promotion requires level 5!';

  @override
  String promoteConfirm(String name, int cost) {
    return 'Promote $name to Line Cook? Cost: $cost €';
  }

  @override
  String get promoteNotEnoughBudget => 'Not enough budget for the promotion!';

  @override
  String promoteSuccess(String name) {
    return '$name is now a Line Cook!';
  }

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
  String get rankChefDePartie => 'Chef de partie';

  @override
  String get rankSousChef => 'Sous-chef';

  @override
  String get rankHeadChef => 'Chef de cuisine';

  @override
  String get station => 'Station';

  @override
  String get stationNone => 'No station chosen';

  @override
  String get stationChoose => 'Choose station';

  @override
  String get stationChooseHint =>
      'The station affects the character itself and acts as an aura for nearby allies.';

  @override
  String stationSwitchConfirm(int cost) {
    return 'Switch station? This costs $cost €.';
  }

  @override
  String get stationNotAllowed =>
      'This station is not selectable here (base station missing).';

  @override
  String stationVariantOf(String base) {
    return 'Variant of $base';
  }

  @override
  String get promoteToChefDePartie => 'Promote to Chef de partie';

  @override
  String promoteLevelRequiredFor(int level) {
    return 'Promotion requires level $level!';
  }

  @override
  String promoteConfirmRank(String name, String rank, int cost) {
    return 'Promote $name to $rank? Cost: $cost €';
  }

  @override
  String get promoteToSousChef => 'Promote to Sous-chef';

  @override
  String get promoteToHeadChef => 'Promote to Chef de cuisine';

  @override
  String get headChefRoleActive => 'Active';

  @override
  String get headChefRoleFormal => 'Formal';

  @override
  String get headChefAssign => 'Make active head chef';

  @override
  String get headChefAssignForbidden =>
      'An active head chef is already assigned.';

  @override
  String headChefAssigned(String name) {
    return '$name now runs the restaurant as active head chef.';
  }

  @override
  String headChefNachrueck(String name) {
    return '$name steps up as active head chef.';
  }

  @override
  String weeklyWage(int amount) {
    return 'Weekly wage: $amount €';
  }

  @override
  String get supportRoles => 'Helper and service roles';

  @override
  String get supportRoleCommunard => 'Communard (staff cook)';

  @override
  String get supportRoleEffectCommunard =>
      'Improves the weekly refill of the colleagues.';

  @override
  String get supportRoleTournant => 'Tournant (roundsman)';

  @override
  String get supportRoleEffectTournant =>
      'Reduces the exhaustion penalty of zero days.';

  @override
  String get supportRoleAboyeur => 'Aboyeur (expediter)';

  @override
  String get supportRoleEffectAboyeur => 'Improves the order flow (income).';

  @override
  String get supportRolePlongeur => 'Plongeur (dishwasher)';

  @override
  String get supportRoleEffectPlongeur => 'Lowers the running operating costs.';

  @override
  String get supportRoleCommis => 'Commis de débarrasseur (busser)';

  @override
  String get supportRoleEffectCommis =>
      'Slightly positive attractiveness effect.';

  @override
  String get supportRoleBoucher => 'Boucher (butcher)';

  @override
  String get supportRoleEffectBoucher => 'Increases the loot after battles.';

  @override
  String get supportRoleGarcon => 'Garçon de cuisine (kitchen boy)';

  @override
  String get supportRoleEffectGarcon =>
      'Small bonus to attractiveness and satisfaction.';

  @override
  String get managementRoles => 'Administration & marketing';

  @override
  String get managementRoleSocialMediaManager => 'Social media manager';

  @override
  String get managementRoleEffectSocialMediaManager =>
      'Increases passive income.';

  @override
  String get managementFeaturePrCampaign => 'PR campaign';

  @override
  String get managementFeaturePrCampaignEffect =>
      'Active ability: temporary XP boost for one team member.';

  @override
  String get managementFeatureActivate => 'Activate feature';

  @override
  String get managementFeatureSelectTarget => 'Choose campaign target';

  @override
  String managementFeatureCost(int cost) {
    return 'Activation: $cost €';
  }

  @override
  String managementFeatureCompetence(int level) {
    return 'Competence $level';
  }

  @override
  String managementFeatureActive(String time) {
    return 'Active until $time';
  }

  @override
  String managementFeatureAftermath(String time) {
    return 'Aftermath until $time';
  }

  @override
  String get managementFeatureNoTargets => 'No available target.';

  @override
  String get managementFeatureActivationFailed => 'Activation not possible.';

  @override
  String get transferTo => 'Move to …';

  @override
  String get transferSelectTitle => 'Choose target restaurant';

  @override
  String transferConfirm(String name, String target, int cost) {
    return 'Move $name to $target? Cost: $cost € – the target restaurant pays.';
  }

  @override
  String transferSuccess(String name, String target) {
    return '$name moves to $target.';
  }

  @override
  String get transferFailed =>
      'Transfer not possible (target dissolved or budget too low).';

  @override
  String get transferNoTargets => 'No other restaurant available.';

  @override
  String get stationSaucier => 'Saucier';

  @override
  String get stationPoissonnier => 'Poissonnier';

  @override
  String get stationRotisseur => 'Rôtisseur';

  @override
  String get stationGrillardin => 'Grillardin';

  @override
  String get stationFriturier => 'Friturier';

  @override
  String get stationEntremetier => 'Entremétier';

  @override
  String get stationPotager => 'Potager';

  @override
  String get stationLegumier => 'Légumier';

  @override
  String get stationGardeManger => 'Garde manger';

  @override
  String get stationCharcutier => 'Charcutier';

  @override
  String get stationPatissier => 'Pâtissier';

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
  String get statusReady => 'Ready';

  @override
  String get statusReeling => 'Reeling';

  @override
  String get statusHurt => 'Hurt';

  @override
  String get statusAfraid => 'Afraid';

  @override
  String get statusInjured => 'Injured';

  @override
  String get statusDying => 'Dying';

  @override
  String get statusDead => 'Dead';

  @override
  String get statusOverkilled => 'Overkilled';

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

  @override
  String nextBillingCountdown(int days) {
    return 'Next billing in $days days';
  }

  @override
  String get budgetWarning =>
      'Warning: the budget is approaching the negative limit!';

  @override
  String customersPerWeekLabel(int count) {
    return '$count customers/week';
  }

  @override
  String passiveIncomeLabel(int income) {
    return 'Passive: $income €/week';
  }

  @override
  String medicCostsLabel(int cost) {
    return 'Medics: $cost €/week';
  }

  @override
  String weeklyLoadTotal(int cost) {
    return 'Total weekly load: $cost €';
  }

  @override
  String get bankruptDialogTitle => 'Bankruptcy!';

  @override
  String get bankruptDialogMessage =>
      'The investors dissolve the restaurant. You start with a new restaurant.';

  @override
  String get bankruptNewRestaurant => 'Start new restaurant';

  @override
  String get cuisineSection => 'Cuisine';

  @override
  String cuisineLabel(String cuisine) {
    return 'Cuisine: $cuisine';
  }

  @override
  String get cuisineItalian => 'Italian';

  @override
  String get cuisineJapanese => 'Japanese';

  @override
  String get cuisineChinese => 'Chinese';

  @override
  String get cuisineGerman => 'German';

  @override
  String get cuisineCanadian => 'Canadian';

  @override
  String get cuisineMexican => 'Mexican';

  @override
  String get rebrandCuisine => 'Change cuisine (rebrand)';

  @override
  String get rebrandDialogTitle => 'Change cuisine?';

  @override
  String rebrandDialogMessage(int cost) {
    return 'The change costs $cost € and temporarily attracts fewer guests.';
  }

  @override
  String get rebrandConfirm => 'Change';

  @override
  String get rebrandSuccess => 'Cuisine changed!';

  @override
  String get rebrandNotEnoughBudget => 'Not enough budget for rebranding!';

  @override
  String get upgradesSection => 'Restaurant upgrades';

  @override
  String get upgradeTables => 'More tables';

  @override
  String get upgradeKitchen => 'Larger kitchen';

  @override
  String get upgradeSignage => 'Advertising signs';

  @override
  String get upgradeDecoration => 'Decorations';

  @override
  String get upgradeJukebox => 'Jukebox';

  @override
  String upgradeLevel(int level, int max) {
    return 'Level $level/$max';
  }

  @override
  String upgradeBuyCost(int cost) {
    return 'Upgrade: $cost €';
  }

  @override
  String upgradeUpkeepCost(int cost) {
    return 'Upkeep: $cost €/week';
  }

  @override
  String get upgradeBuy => 'Upgrade';

  @override
  String get upgradeDowngrade => 'Downgrade';

  @override
  String get upgradeSell => 'Sell';

  @override
  String get upgradeMaxReached => 'Max level';

  @override
  String get upgradeNotEnoughBudget => 'Not enough budget for the upgrade!';

  @override
  String upgradeSold(int amount) {
    return 'Sold: +$amount €';
  }

  @override
  String get tabPersonnel => 'Active staff';

  @override
  String get tabMedics => 'Team medic';

  @override
  String get tabUpgrades => 'Upgrades';

  @override
  String get tabBattle => 'Map & battle';

  @override
  String rebrandingPenaltyActive(int days) {
    return 'Rebrand active: attractiveness −1 ($days days left)';
  }

  @override
  String healCountdown(int hours, int minutes) {
    return 'Fully healed in ~$hours h $minutes min';
  }

  @override
  String shotCountdown(int hours, int minutes) {
    return 'Relapse in ~$hours h $minutes min';
  }

  @override
  String catchUpSummary(
    int weeks,
    int income,
    int medicCosts,
    int upkeep,
    int interest,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: '$weeks weeks settled',
      one: '1 week settled',
    );
    return '$_temp0: income +$income €, medic −$medicCosts €, upkeep −$upkeep €, interest −$interest €';
  }

  @override
  String catchUpLeftover(int days, int income) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days leftover days',
      one: '1 leftover day',
    );
    return '$_temp0 income: +$income €';
  }

  @override
  String get healingComplete => 'Fully fit for duty';

  @override
  String personalityLabel(String name) {
    return 'Personality: $name';
  }

  @override
  String resourcesLine(int vitality, int morale) {
    return 'Vitality $vitality/100 · Morale $morale/100';
  }

  @override
  String stressCountdown(String time) {
    return 'Stressed – switching until $time';
  }

  @override
  String ruheCountdown(String time) {
    return 'At ease – switching until $time';
  }

  @override
  String resourceZeroMalus(int malus) {
    return 'Exhausted: −$malus % on all rolls';
  }

  @override
  String medicScores(int helpfulness, int treatment) {
    return 'Helpfulness $helpfulness · Treatment quality $treatment';
  }
}
