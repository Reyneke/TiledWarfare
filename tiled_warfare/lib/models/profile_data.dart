import 'package:tiled_warfare/models/cuisine.dart';
import 'package:tiled_warfare/models/match_record.dart';
import 'package:tiled_warfare/models/restaurant_upgrade.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/utils/json_utils.dart';

/// Default starting budget of a restaurant (EUR).
///
/// Used when creating new restaurants and as the fallback value in the
/// JSON deserializers. Referenced as `ObjectProfile.startBudget`.
const int kDefaultRestaurantBudget = EconomyBalance.startBudget;

/// Aktuelle Schema-Version der gespeicherten Spielstände (V6).
///
/// Version 1 = Alt-Bestände ohne `version`-Feld, Version 2 = aktuelle
/// Struktur. Die Deserialisierung ist bewusst toleranter als die Version:
/// fehlende oder unbekannte Felder führen zu Defaults statt zu Fehlern.
const int kProfileSchemaVersion = 2;

/// Liest eine Liste von JSON-Objekten tolerant nach [T] (V6).
///
/// Nicht-Objekte und fehlerhafte Einträge werden übersprungen statt eine
/// Exception zu werfen.
List<T> _mapList<T>(dynamic value, T Function(Map<String, dynamic>) fromJson) {
  if (value is! List) return const [];
  final result = <T>[];
  for (final entry in value) {
    if (entry is Map) {
      result.add(fromJson(Map<String, dynamic>.from(entry)));
    }
  }
  return result;
}

/// Bildet einen optionalen [MatchResult]-Namen ab (unbekannt → `null`).
MatchResult? _matchResultFromName(String? name) {
  if (name == null) return null;
  for (final value in MatchResult.values) {
    if (value.name == name) return value;
  }
  return null;
}


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
        'version': kProfileSchemaVersion,
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
  ///
  /// Bewusst tolerant (V6): fehlende oder falsch typisierte Felder führen zu
  /// Defaults, nicht zu einer Exception. Ein einzelner defekter Wert kann so
  /// nicht mehr das Laden des gesamten Bestands verhindern.
  factory ProfileData.fromJson(Map<String, dynamic> json) => ProfileData(
        id: readInt(json['id']) ?? -1,
        name: readString(json['name']) ?? '',
        creationDate: readDateTime(json['creationDate']) ?? DateTime.now(),
        budget: readInt(json['budget']) ?? kDefaultRestaurantBudget,
        profileImagePath: readString(json['profileImagePath']),
        staff: _mapList(json['staff'], StaffData.fromJson),
        medics: _mapList(json['medics'], MedicData.fromJson),
        restaurants: _mapList(json['restaurants'], RestaurantData.fromJson),
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

  /// Tolerante Deserialisierung (V6): fehlende/falsche Felder → Defaults.
  factory StaffData.fromJson(Map<String, dynamic> json) => StaffData(
        name: readString(json['name']) ?? '',
        imagePath: readString(json['imagePath']) ?? '',
        type: readString(json['type']) ?? 'apprentice',
        levelValue: readInt(json['levelValue']) ?? 1,
        currentXPValue: readInt(json['currentXPValue']) ?? 0,
        woundValue: readInt(json['woundValue']) ?? 3,
        attackValue: readInt(json['attackValue']) ?? 40,
        defenseValue: readInt(json['defenseValue']) ?? 20,
        movementValue: readInt(json['movementValue']) ?? 6,
        damageValue: readInt(json['damageValue']) ?? 2,
        rangeValue: readInt(json['rangeValue']) ?? 3,
        moneyValue: readInt(json['moneyValue']) ?? 100,
        xpValue: readInt(json['xpValue']) ?? 25,
        status: readString(json['status']) ?? 'ready',
        injuryStartedAt: readDateTime(json['injuryStartedAt']),
        injuryStartStatus: readString(json['injuryStartStatus']),
        emergencyShotAt: readDateTime(json['emergencyShotAt']),
        suppressedStatus: readString(json['suppressedStatus']),
        matchHistory: readMapList(json['matchHistory']),
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

  /// Tolerante Deserialisierung (V6): fehlende/falsche Felder → Defaults.
  factory MedicData.fromJson(Map<String, dynamic> json) => MedicData(
        id: readInt(json['id']) ?? -1,
        name: readString(json['name']) ?? '',
        quality: readString(json['quality']) ?? 'niedrig',
        costPerWeek: readInt(json['costPerWeek']) ?? 0,
        enneagramProfileName: readString(json['enneagramProfileName']) ?? '',
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

  /// Tolerante Deserialisierung (V6): fehlende/falsche Felder → Defaults.
  factory RestaurantData.fromJson(Map<String, dynamic> json) => RestaurantData(
        id: readInt(json['id']) ?? -1,
        name: readString(json['name']) ?? '',
        logoPath: readString(json['logoPath']),
        district: readString(json['district']),
        cuisine: Cuisine.fromName(readString(json['cuisine'])),
        rebrandingPenaltyUntil:
            readDateTime(json['rebrandingPenaltyUntil']),
        budget: readInt(json['budget']) ?? kDefaultRestaurantBudget,
        staff: _mapList(json['staff'], StaffData.fromJson),
        medics: _mapList(json['medics'], MedicData.fromJson),
        lastSeenAt: readDateTime(json['lastSeenAt']),
        isDissolved: readBool(json['isDissolved']) ?? false,
        dissolvedAt: readDateTime(json['dissolvedAt']),
        lastMatchResult:
            _matchResultFromName(readString(json['lastMatchResult'])),
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
