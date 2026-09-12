import 'package:tiled_warfare/models/cuisine.dart';
import 'package:tiled_warfare/models/match_record.dart';
import 'package:tiled_warfare/models/restaurant_upgrade.dart';
import 'package:tiled_warfare/services/economy_balance.dart';

/// Default starting budget of a restaurant (EUR).
///
/// Used when creating new restaurants and as the fallback value in the
/// JSON deserializers. Referenced as `ObjectProfile.startBudget`.
const int kDefaultRestaurantBudget = EconomyBalance.startBudget;


/// Datenmodell für ein einzelnes Nutzerprofil.
///
/// Enthält alle Informationen, die lokal gespeichert werden:
/// - Eine eindeutige ID (CRC32-Hash aus Name + Erstellungsdatum)
/// - Den Namen des Profils (Spieler-Name)
/// - Das Erstellungsdatum
/// - Budget, Profilbild-Pfad und Personal-Daten
/// - Eine Liste der zugehörigen Restaurants
class ProfileData {
  /// Eindeutige ID (CRC32-Hash).
  final int id;

  /// Name des Profils (Spieler-Name).
  String name;

  /// Erstellungsdatum des Profils.
  final DateTime creationDate;

  /// Aktuelles Budget in Euro.
  int budget;

  /// Pfad zum Profilbild (optional).
  String? profileImagePath;

  /// Liste der angestellten Charaktere (serialisiert).
  final List<StaffData> staff;

  /// Liste der angestellten Teamärzte (serialisiert).
  final List<MedicData> medics;

  /// Liste der zu diesem Profil gehörenden Restaurants.
  final List<RestaurantData> restaurants;

  ProfileData({
    required this.id,
    required this.name,
    required this.creationDate,
    this.budget = kDefaultRestaurantBudget,
    this.profileImagePath,
    List<StaffData>? staff,
    List<MedicData>? medics,
    List<RestaurantData>? restaurants,
  })  : staff = staff ?? [],
        medics = medics ?? [],
        restaurants = restaurants ?? [];

  /// Erzeugt einen JSON-kompatiblen Map-Repräsentation.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'creationDate': creationDate.toIso8601String(),
        if (profileImagePath != null) 'profileImagePath': profileImagePath,
        // Profile level no longer holds any play state: budget/staff/medics
        // live per restaurant (V1 "mehrere Restaurants"). fromJson still reads
        // the legacy fields so they can be migrated once on load.
        'restaurants': restaurants.map((r) => r.toJson()).toList(),
      };

  /// Erzeugt ein [ProfileData] aus einer JSON-Map.
  factory ProfileData.fromJson(Map<String, dynamic> json) => ProfileData(
        id: json['id'] as int,
        name: json['name'] as String,
        creationDate: DateTime.parse(json['creationDate'] as String),
        budget: json['budget'] as int? ?? kDefaultRestaurantBudget,
        profileImagePath: json['profileImagePath'] as String?,
        staff: (json['staff'] as List<dynamic>?)
                ?.map((e) => StaffData.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        medics: (json['medics'] as List<dynamic>?)
                ?.map((e) => MedicData.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        restaurants: (json['restaurants'] as List<dynamic>?)
                ?.map((e) => RestaurantData.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  @override
  String toString() =>
      'ProfileData(id=$id, name=$name, budget=$budget, '
      'staff=${staff.length}, medics=${medics.length}, '
      'restaurants=${restaurants.length})';
}

/// Serialisierbare Daten eines angestellten Charakters.
class StaffData {
  /// Name des Charakters.
  String name;

  /// Pfad zum Token-Bild.
  String imagePath;

  /// Typ: 'apprentice' oder 'line_cook'.
  String type;

  int levelValue;
  int currentXPValue;
  int woundValue;
  int attackValue;
  int defenseValue;
  int movementValue;
  int damageValue;
  int rangeValue;
  int moneyValue;
  int xpValue;
  String status;

  /// Beginn der aktuellen Verletzung (V3) – Anker der Echtzeit-Heilung.
  DateTime? injuryStartedAt;

  /// Status zu Beginn der aktuellen Verletzung (V3).
  ///
  /// Nötig für die idempotente Neuberechnung: Der Heilungsfortschritt wird
  /// immer aus diesem Ausgangsstatus + verstrichener Zeit hergeleitet, nie
  /// fortgeschrieben.
  String? injuryStartStatus;

  /// Zeitpunkt der automatisch verabreichten Notfall-Spritze (V3).
  DateTime? emergencyShotAt;

  /// Der von der Notfall-Spritze unterdrückte Status (V3).
  String? suppressedStatus;

  /// Match-Historie (serialisiert als Liste von Maps).
  List<Map<String, dynamic>> matchHistory;

  StaffData({
    required this.name,
    required this.imagePath,
    required this.type,
    this.levelValue = 1,
    this.currentXPValue = 0,
    this.woundValue = 3,
    this.attackValue = 40,
    this.defenseValue = 20,
    this.movementValue = 6,
    this.damageValue = 2,
    this.rangeValue = 3,
    this.moneyValue = 100,
    this.xpValue = 25,
    this.status = 'ready',
    this.injuryStartedAt,
    this.injuryStartStatus,
    this.emergencyShotAt,
    this.suppressedStatus,
    List<Map<String, dynamic>>? matchHistory,
  }) : matchHistory = matchHistory ?? [];

  Map<String, dynamic> toJson() => {
        'name': name,
        'imagePath': imagePath,
        'type': type,
        'levelValue': levelValue,
        'currentXPValue': currentXPValue,
        'woundValue': woundValue,
        'attackValue': attackValue,
        'defenseValue': defenseValue,
        'movementValue': movementValue,
        'damageValue': damageValue,
        'rangeValue': rangeValue,
        'moneyValue': moneyValue,
        'xpValue': xpValue,
        'status': status,
        if (injuryStartedAt != null)
          'injuryStartedAt': injuryStartedAt!.toIso8601String(),
        if (injuryStartStatus != null) 'injuryStartStatus': injuryStartStatus,
        if (emergencyShotAt != null)
          'emergencyShotAt': emergencyShotAt!.toIso8601String(),
        if (suppressedStatus != null) 'suppressedStatus': suppressedStatus,
        'matchHistory': matchHistory,
      };

  factory StaffData.fromJson(Map<String, dynamic> json) => StaffData(
        name: json['name'] as String,
        imagePath: json['imagePath'] as String,
        type: json['type'] as String,
        levelValue: json['levelValue'] as int? ?? 1,
        currentXPValue: json['currentXPValue'] as int? ?? 0,
        woundValue: json['woundValue'] as int? ?? 3,
        attackValue: json['attackValue'] as int? ?? 40,
        defenseValue: json['defenseValue'] as int? ?? 20,
        movementValue: json['movementValue'] as int? ?? 6,
        damageValue: json['damageValue'] as int? ?? 2,
        rangeValue: json['rangeValue'] as int? ?? 3,
        moneyValue: json['moneyValue'] as int? ?? 100,
        xpValue: json['xpValue'] as int? ?? 25,
        status: json['status'] as String? ?? 'ready',
        injuryStartedAt: json['injuryStartedAt'] == null
            ? null
            : DateTime.parse(json['injuryStartedAt'] as String),
        injuryStartStatus: json['injuryStartStatus'] as String?,
        emergencyShotAt: json['emergencyShotAt'] == null
            ? null
            : DateTime.parse(json['emergencyShotAt'] as String),
        suppressedStatus: json['suppressedStatus'] as String?,
        matchHistory: (json['matchHistory'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      );
}

/// Serialisierbare Daten eines angestellten Teamarztes.
class MedicData {
  /// Eindeutige ID des Teamarztes.
  final int id;

  /// Name des Teamarztes.
  final String name;

  /// Qualitätsstufe als String ('niedrig', 'mittel', 'hoch').
  final String quality;

  /// Wöchentliche Kosten in Euro.
  final int costPerWeek;

  /// Name des Enneagramm-Profils.
  final String enneagramProfileName;

  MedicData({
    required this.id,
    required this.name,
    required this.quality,
    required this.costPerWeek,
    required this.enneagramProfileName,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'quality': quality,
        'costPerWeek': costPerWeek,
        'enneagramProfileName': enneagramProfileName,
      };

  factory MedicData.fromJson(Map<String, dynamic> json) => MedicData(
        id: json['id'] as int,
        name: json['name'] as String,
        quality: json['quality'] as String,
        costPerWeek: json['costPerWeek'] as int,
        enneagramProfileName: json['enneagramProfileName'] as String,
      );
}

/// Datenmodell für ein Restaurant innerhalb eines Profils.
class RestaurantData {
  /// Stable, unique id of the savegame (CRC32 of name + creation time).
  /// `-1` marks an as-yet unassigned id (legacy data -> migration assigns one).
  int id;

  /// Name of the restaurant.
  String name;

  /// Path to the logo image (optional).
  String? logoPath;

  /// District (location) of the restaurant - a name from the "Nachbarschaften"
  /// object layer in `assets/world/theworld.tmx`. At most one restaurant per
  /// district and profile.
  String? district;

  /// Küche (Konzept) des Restaurants; bestimmt den Namensstamm des Personals
  /// (§ 9). Alt-Spielstände ohne Feld sind italienisch.
  Cuisine cuisine;

  /// Bis wann der Attraktivitäts-Malus nach einem Rebranding gilt (§ 9).
  DateTime? rebrandingPenaltyUntil;

  /// Budget of this savegame (starts at [kDefaultRestaurantBudget]).
  int budget;

  /// Hired characters of this savegame (serialized).
  List<StaffData> staff;

  /// Hired team medics of this savegame (serialized).
  List<MedicData> medics;

  /// Last played timestamp (reserved for the realtime system, V8).
  DateTime? lastSeenAt;

  /// `true` once the savegame has been dissolved after permadeath.
  bool isDissolved;

  /// Timestamp of the dissolution (optional, for display / V8).
  DateTime? dissolvedAt;

  /// Ergebnis des jüngsten Gefechts (Quelle für den `resultBonus` des
  /// passiven Einkommens, § 8).
  MatchResult? lastMatchResult;

  /// Ausbaustufen der Restaurant-Erweiterungen (§ 10).
  Map<UpgradeType, int> upgrades;

  RestaurantData({
    this.id = -1,
    required this.name,
    this.logoPath,
    this.district,
    this.cuisine = Cuisine.italian,
    this.rebrandingPenaltyUntil,
    this.budget = kDefaultRestaurantBudget,
    List<StaffData>? staff,
    List<MedicData>? medics,
    this.lastSeenAt,
    this.isDissolved = false,
    this.dissolvedAt,
    this.lastMatchResult,
    Map<UpgradeType, int>? upgrades,
  })  : staff = staff ?? [],
        medics = medics ?? [],
        upgrades = upgrades ?? {};

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (logoPath != null) 'logoPath': logoPath,
        if (district != null) 'district': district,
        'cuisine': cuisine.name,
        if (rebrandingPenaltyUntil != null)
          'rebrandingPenaltyUntil': rebrandingPenaltyUntil!.toIso8601String(),
        'budget': budget,
        'staff': staff.map((s) => s.toJson()).toList(),
        'medics': medics.map((m) => m.toJson()).toList(),
        if (lastSeenAt != null) 'lastSeenAt': lastSeenAt!.toIso8601String(),
        'isDissolved': isDissolved,
        if (dissolvedAt != null) 'dissolvedAt': dissolvedAt!.toIso8601String(),
        if (lastMatchResult != null) 'lastMatchResult': lastMatchResult!.name,
        'upgrades': {
          for (final entry in upgrades.entries) entry.key.name: entry.value,
        },
      };

  factory RestaurantData.fromJson(Map<String, dynamic> json) => RestaurantData(
        id: json['id'] as int? ?? -1,
        name: json['name'] as String,
        logoPath: json['logoPath'] as String?,
        district: json['district'] as String?,
        cuisine: Cuisine.fromName(json['cuisine'] as String?),
        rebrandingPenaltyUntil: json['rebrandingPenaltyUntil'] == null
            ? null
            : DateTime.parse(json['rebrandingPenaltyUntil'] as String),
        budget: json['budget'] as int? ?? kDefaultRestaurantBudget,
        staff: (json['staff'] as List<dynamic>?)
                ?.map((e) => StaffData.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        medics: (json['medics'] as List<dynamic>?)
                ?.map((e) => MedicData.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        lastSeenAt: json['lastSeenAt'] == null
            ? null
            : DateTime.parse(json['lastSeenAt'] as String),
        isDissolved: json['isDissolved'] as bool? ?? false,
        dissolvedAt: json['dissolvedAt'] == null
            ? null
            : DateTime.parse(json['dissolvedAt'] as String),
        lastMatchResult: json['lastMatchResult'] == null
            ? null
            : MatchResult.values.firstWhere(
                (e) => e.name == json['lastMatchResult'],
                orElse: () => MatchResult.draw,
              ),
        upgrades: _upgradesFromJson(json['upgrades']),
      );

  /// Liest die Erweiterungs-Stufen aus dem JSON (unbekannte Typen werden
  /// ignoriert – abwärtskompatibel).
  static Map<UpgradeType, int> _upgradesFromJson(dynamic json) {
    final result = <UpgradeType, int>{};
    if (json is Map) {
      json.forEach((key, value) {
        if (value is int) {
          for (final type in UpgradeType.values) {
            if (type.name == key) {
              result[type] = value;
              break;
            }
          }
        }
      });
    }
    return result;
  }

  @override
  String toString() => 'RestaurantData(id=$id, name=$name, district=$district, '
      'budget=$budget, staff=${staff.length}, medics=${medics.length}, '
      'isDissolved=$isDissolved)';
}
