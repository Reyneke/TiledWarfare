import 'package:tiled_warfare/models/cuisine.dart';
import 'package:tiled_warfare/models/match_record.dart';
import 'package:tiled_warfare/models/restaurant_upgrade.dart';
import 'package:tiled_warfare/models/staff_entry.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/utils/json_utils.dart';

/// Default starting budget of a restaurant (EUR).
///
/// Used when creating new restaurants and as the fallback value in the
/// JSON deserializers. Referenced as `ObjectProfile.startBudget`.
const int kDefaultRestaurantBudget = EconomyBalance.startBudget;

/// Aktuelle Schema-Version der gespeicherten Spielstände (V6).
///
/// Version 1 = Alt-Bestände ohne `version`-Feld, Version 2 = Restaurant-Ebene,
/// Version 3 = Personal-Identität/Attribute (V9), Version 4 = Karriere-Rang &
/// Station (Karrierepfade, V10), Version 5 = Hilfs-/Service-Rollen (V10),
/// Version 6 = generalisiertes Nicht-Kampf-Personal (`StaffEntryData`, Option C).
/// Die Deserialisierung ist bewusst toleranter als die Version: fehlende oder
/// unbekannte Felder führen zu Defaults statt zu Fehlern.
const int kProfileSchemaVersion = 6;

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

/// Karriere-Rang-Schlüssel des Personals (Karrierepfade, V10).
///
/// Die Werte sind stabil und dienen als Persistenz-Schlüssel (nie der
/// Anzeigename). Die ersten beiden entsprechen den bisherigen [StaffData.type]-
/// Werten, damit die Migration verlustfrei ist.
const String kRankApprentice = 'apprentice';
const String kRankLineCook = 'line_cook';
const String kRankChefDePartie = 'chef_de_partie';
const String kRankSousChef = 'sous_chef';
const String kRankHeadChef = 'head_chef';

/// Rollen-Schlüssel des `Chef de cuisine` (Karrierepfade): aktiv oder formell.
const String kHeadChefRoleActive = 'aktiv';
const String kHeadChefRoleFormal = 'formell';

/// Leitet den Karriere-Rang aus dem (Legacy-)Klassen-Schlüssel [type] ab.
String rankFromType(String? type) => switch (type) {
      kRankLineCook => kRankLineCook,
      _ => kRankApprentice,
    };


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

  /// Typ: 'apprentice' oder 'line_cook' (Legacy-Klassen-Schlüssel).
  ///
  /// Bleibt für die Abwärtskompatibilität erhalten und wird weiterhin
  /// geschrieben; für die Karriere-Ränge ist [rank] führend (Karrierepfade, V10).
  String type;

  /// Karriere-Rang (Karrierepfade, V10) – stabiler Schlüssel, nie der
  /// Anzeigename. Einer der `kRank*`-Werte.
  String rank;

  /// Gewählte Station (Karrierepfade) – `null`, solange keine gewählt wurde.
  /// Erst ab Rang `chef_de_partie` gesetzt.
  String? station;

  /// Rolle eines `Chef de cuisine`: `aktiv` oder `formell` (Karrierepfade).
  /// `null` für alle anderen Ränge.
  String? headChefRole;

  /// Restaurant-ID, der ein **aktiver** `Chef de cuisine` zugeteilt ist
  /// (Karrierepfade). `null`, wenn nicht zugeteilt.
  int? assignedRestaurantId;

  /// Stabile Charakter-ID (CRC32 aus Name + Erzeugungszeitpunkt).
  ///
  /// `-1` markiert eine noch nicht zugewiesene ID (V9).
  int id;

  /// Index des Enneagramm-Profils in `EnneagramProfile.all` (V9).
  ///
  /// `-1` markiert ein noch nicht zugewiesenes Profil (Alt-Daten).
  int personalityId;

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

  /// Aktueller Vitalitätsstand (V9) – `null` bei Alt-Daten (wird beim Laden
  /// aus den Persönlichkeits-Traits abgeleitet).
  int? vitalityCurrent;

  /// Aktueller Moralstand (V9) – `null` bei Alt-Daten.
  int? moraleCurrent;

  /// Anker für idempotentes Sinken/Auffüllen der Ressourcen (V9).
  DateTime? lastResourceRefillAt;

  /// Temporär wirksames Enneagramm-Profil (Stress/Ruhe, V9 § 6); `-1` = keins.
  int personalityOverrideId;

  /// Ablaufzeitpunkt des Overrides (V9 § 6).
  DateTime? personalityOverrideUntil;

  /// Auslöser des Overrides: `stress` oder `ruhe` (V9 § 6).
  String? personalityOverrideCause;

  /// Seit wann `vitalityCurrent` auf 0 steht (Erschöpfungs-Malus, V9 § 6).
  DateTime? vitalityZeroSinceAt;

  /// Seit wann `moraleCurrent` auf 0 steht (Erschöpfungs-Malus, V9 § 6).
  DateTime? moraleZeroSinceAt;

  /// Match-Historie (serialisiert als Liste von Maps).
  List<Map<String, dynamic>> matchHistory;

  StaffData({
    required this.name,
    required this.imagePath,
    required this.type,
    String? rank,
    this.station,
    this.headChefRole,
    this.assignedRestaurantId,
    this.id = -1,
    this.personalityId = -1,
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
    this.vitalityCurrent,
    this.moraleCurrent,
    this.lastResourceRefillAt,
    this.personalityOverrideId = -1,
    this.personalityOverrideUntil,
    this.personalityOverrideCause,
    this.vitalityZeroSinceAt,
    this.moraleZeroSinceAt,
    List<Map<String, dynamic>>? matchHistory,
  })  : rank = rank ?? rankFromType(type),
        matchHistory = matchHistory ?? [];

  Map<String, dynamic> toJson() => {
        'name': name,
        'imagePath': imagePath,
        'type': type,
        'rank': rank,
        if (station != null) 'station': station,
        if (headChefRole != null) 'headChefRole': headChefRole,
        if (assignedRestaurantId != null)
          'assignedRestaurantId': assignedRestaurantId,
        'id': id,
        'personalityId': personalityId,
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
        if (vitalityCurrent != null) 'vitalityCurrent': vitalityCurrent,
        if (moraleCurrent != null) 'moraleCurrent': moraleCurrent,
        if (lastResourceRefillAt != null)
          'lastResourceRefillAt': lastResourceRefillAt!.toIso8601String(),
        'personalityOverrideId': personalityOverrideId,
        if (personalityOverrideUntil != null)
          'personalityOverrideUntil':
              personalityOverrideUntil!.toIso8601String(),
        if (personalityOverrideCause != null)
          'personalityOverrideCause': personalityOverrideCause,
        if (vitalityZeroSinceAt != null)
          'vitalityZeroSinceAt': vitalityZeroSinceAt!.toIso8601String(),
        if (moraleZeroSinceAt != null)
          'moraleZeroSinceAt': moraleZeroSinceAt!.toIso8601String(),
        'matchHistory': matchHistory,
      };

  /// Tolerante Deserialisierung (V6): fehlende/falsche Felder → Defaults.
  factory StaffData.fromJson(Map<String, dynamic> json) => StaffData(
        name: readString(json['name']) ?? '',
        imagePath: readString(json['imagePath']) ?? '',
        type: readString(json['type']) ?? kRankApprentice,
        rank: readString(json['rank']),
        station: readString(json['station']),
        headChefRole: readString(json['headChefRole']),
        assignedRestaurantId: readInt(json['assignedRestaurantId']),
        id: readInt(json['id']) ?? -1,
        personalityId: readInt(json['personalityId']) ?? -1,
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
        vitalityCurrent: readInt(json['vitalityCurrent']),
        moraleCurrent: readInt(json['moraleCurrent']),
        lastResourceRefillAt: readDateTime(json['lastResourceRefillAt']),
        personalityOverrideId: readInt(json['personalityOverrideId']) ?? -1,
        personalityOverrideUntil: readDateTime(json['personalityOverrideUntil']),
        personalityOverrideCause: readString(json['personalityOverrideCause']),
        vitalityZeroSinceAt: readDateTime(json['vitalityZeroSinceAt']),
        moraleZeroSinceAt: readDateTime(json['moraleZeroSinceAt']),
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

  /// Stabiler Profil-Index (V9) – bevorzugt beim Laden; `null` = Alt-Daten.
  final int? personalityId;

  MedicData({
    required this.id,
    required this.name,
    required this.quality,
    required this.costPerWeek,
    required this.enneagramProfileName,
    this.personalityId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'quality': quality,
        'costPerWeek': costPerWeek,
        'enneagramProfileName': enneagramProfileName,
        if (personalityId != null) 'personalityId': personalityId,
      };

  /// Tolerante Deserialisierung (V6): fehlende/falsche Felder → Defaults.
  factory MedicData.fromJson(Map<String, dynamic> json) => MedicData(
        id: readInt(json['id']) ?? -1,
        name: readString(json['name']) ?? '',
        quality: readString(json['quality']) ?? 'niedrig',
        costPerWeek: readInt(json['costPerWeek']) ?? 0,
        enneagramProfileName: readString(json['enneagramProfileName']) ?? '',
        personalityId: readInt(json['personalityId']),
      );
}

/// Serialisierbare Daten einer Hilfs-/Service-Rolle (Karrierepfade, V10).
///
/// Diese Rollen ziehen **nicht** ins Gefecht; sie wirken auf die
/// Management-Schleife und werden wie die Teamärzte verwaltet. Der Rollen-Typ
/// wird als stabiler String (`SupportRole.name`) persistiert.
class SupportRoleData {
  /// Stabile ID (CRC32 aus Name + Anstellungszeitpunkt).
  final int id;

  /// Anzeigename der angestellten Person.
  final String name;

  /// Rollen-Schlüssel (`SupportRole.name`); unbekannte Werte werden beim Laden
  /// übersprungen (tolerant, V6).
  final String role;

  /// Wöchentlicher Lohn in Euro.
  final int costPerWeek;

  /// Zeitpunkt der Anstellung (optional, für Sortierung/Anzeige).
  final DateTime? hiredAt;

  SupportRoleData({
    required this.id,
    required this.name,
    required this.role,
    required this.costPerWeek,
    this.hiredAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'costPerWeek': costPerWeek,
        if (hiredAt != null) 'hiredAt': hiredAt!.toIso8601String(),
      };

  /// Tolerante Deserialisierung (V6): fehlende/falsche Felder → Defaults.
  factory SupportRoleData.fromJson(Map<String, dynamic> json) =>
      SupportRoleData(
        id: readInt(json['id']) ?? -1,
        name: readString(json['name']) ?? '',
        role: readString(json['role']) ?? '',
        costPerWeek: readInt(json['costPerWeek']) ?? 0,
        hiredAt: readDateTime(json['hiredAt']),
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

  /// Angestellte Hilfs-/Service-Rollen dieses Spielstands (serialized, V10).
  ///
  /// Bleibt für **Abwärtskompatibilität** erhalten und wird weiter geschrieben;
  /// die Perspektive ist [staffEntries] (Option C, `11a`).
  List<SupportRoleData> supportStaff;

  /// Angestelltes **Nicht-Kampf-Personal** aller Kategorien (Option C, `11a`).
  ///
  /// Generalisierter Eintragstyp mit Kategorie (`RoleKind`). Alt-Spielstände
  /// ohne dieses Feld werden beim Laden aus [supportStaff] migriert
  /// (`kind = support`), solange [staffEntries] leer ist.
  List<StaffEntryData> staffEntries;

  /// Zeitanker des Echtzeit-Systems (V8/§ 6): bis hierhin sind alle **vollen
  /// Echtzeittage** abgerechnet (Tages-Schritt). Wird nur um abgerechnete Tage
  /// fortgeschrieben (der Sub-Tag-Rest bleibt erhalten), damit der Tagestakt
  /// auch bei häufigem Nachrechnen nicht verloren geht.
  DateTime? lastSeenAt;

  /// Beginn des laufenden 7-Tage-Blocks (Wochenanker, § 6).
  ///
  /// Wird nur um **volle Wochen** fortgeschrieben, damit das Wochenraster nicht
  /// mit jedem Catch-up verschoben wird. Alt-Stände ohne Feld: Fallback auf
  /// [lastSeenAt].
  DateTime? weekAnchorAt;

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
    List<SupportRoleData>? supportStaff,
    List<StaffEntryData>? staffEntries,
    this.lastSeenAt,
    this.weekAnchorAt,
    this.isDissolved = false,
    this.dissolvedAt,
    this.lastMatchResult,
    Map<UpgradeType, int>? upgrades,
  })  : staff = staff ?? [],
        medics = medics ?? [],
        supportStaff = supportStaff ?? [],
        staffEntries = _resolveStaffEntries(staffEntries, supportStaff),
        upgrades = upgrades ?? {};

  /// Vereinheitlicht [staffEntries] und die Alt-Bestände aus [supportStaff]
  /// (Option C, `11a`): Ein nicht-leeres [staffEntries] hat Vorrang; andernfalls
  /// werden die Küchen-Rollen als `kind = support` importiert.
  static List<StaffEntryData> _resolveStaffEntries(
    List<StaffEntryData>? staffEntries,
    List<SupportRoleData>? supportStaff,
  ) {
    if (staffEntries != null && staffEntries.isNotEmpty) return staffEntries;
    return <StaffEntryData>[
      for (final entry in supportStaff ?? const <SupportRoleData>[])
        StaffEntryData(
          id: entry.id,
          name: entry.name,
          kind: RoleKind.support,
          role: entry.role,
          costPerWeek: entry.costPerWeek,
          hiredAt: entry.hiredAt,
        ),
    ];
  }

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
        'supportStaff': supportStaff.map((s) => s.toJson()).toList(),
        'staffEntries': staffEntries.map((s) => s.toJson()).toList(),
        if (lastSeenAt != null) 'lastSeenAt': lastSeenAt!.toIso8601String(),
        if (weekAnchorAt != null)
          'weekAnchorAt': weekAnchorAt!.toIso8601String(),
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
        supportStaff:
            _mapList(json['supportStaff'], SupportRoleData.fromJson),
        staffEntries: json['staffEntries'] == null
            ? null
            : _mapList(json['staffEntries'], StaffEntryData.fromJson),
        lastSeenAt: readDateTime(json['lastSeenAt']),
        weekAnchorAt: readDateTime(json['weekAnchorAt']),
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

  /// Erzeugt eine Kopie mit ersetzter [staff]-Liste und/oder [budget]
  /// (Karrierepfade, V10).
  ///
  /// Wird beim Merging genutzt, um gezielt **nicht-aktive** Restaurants zu
  /// verändern (z. B. Personal-Transfer), ohne das Objekt in `ProfileData`
  /// in-place zu mutieren.
  RestaurantData copyWith({List<StaffData>? staff, int? budget}) =>
      RestaurantData(
        id: id,
        name: name,
        logoPath: logoPath,
        district: district,
        cuisine: cuisine,
        rebrandingPenaltyUntil: rebrandingPenaltyUntil,
        budget: budget ?? this.budget,
        staff: staff ?? this.staff,
        medics: medics,
        supportStaff: supportStaff,
        staffEntries: staffEntries,
        lastSeenAt: lastSeenAt,
        weekAnchorAt: weekAnchorAt,
        isDissolved: isDissolved,
        dissolvedAt: dissolvedAt,
        lastMatchResult: lastMatchResult,
        upgrades: upgrades,
      );

  @override
  String toString() => 'RestaurantData(id=$id, name=$name, district=$district, '
      'budget=$budget, staff=${staff.length}, medics=${medics.length}, '
      'isDissolved=$isDissolved)';
}
