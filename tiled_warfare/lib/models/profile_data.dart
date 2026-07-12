import 'package:tiled_warfare/models/match_record.dart';
import 'package:tiled_warfare/objects/object_host.dart';

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
    this.budget = 10000,
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
        'budget': budget,
        if (profileImagePath != null) 'profileImagePath': profileImagePath,
        'staff': staff.map((s) => s.toJson()).toList(),
        'medics': medics.map((m) => m.toJson()).toList(),
        'restaurants': restaurants.map((r) => r.toJson()).toList(),
      };

  /// Erzeugt ein [ProfileData] aus einer JSON-Map.
  factory ProfileData.fromJson(Map<String, dynamic> json) => ProfileData(
        id: json['id'] as int,
        name: json['name'] as String,
        creationDate: DateTime.parse(json['creationDate'] as String),
        budget: json['budget'] as int? ?? 10000,
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
  /// Name des Restaurants.
  String name;

  /// Pfad zum Logo-Bild (optional).
  String? logoPath;

  RestaurantData({
    required this.name,
    this.logoPath,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        if (logoPath != null) 'logoPath': logoPath,
      };

  factory RestaurantData.fromJson(Map<String, dynamic> json) => RestaurantData(
        name: json['name'] as String,
        logoPath: json['logoPath'] as String?,
      );

  @override
  String toString() => 'RestaurantData(name=$name)';
}