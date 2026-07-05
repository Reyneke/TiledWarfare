import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/objects/object_player.dart';
import 'package:tiled_warfare/objects/player_objects/object_appretice.dart';
import 'package:tiled_warfare/objects/player_objects/object_line_cook.dart';
import 'package:tiled_warfare/services/profile_storage.dart';

/// Verwaltet das Restaurant und alle Dinge, die ausserhalb des Gefechts
/// stattfinden (Teamverwaltung, Budget, Anheuerung etc.).
///
/// Dieses Objekt ist dem [ObjectPlayer] übergeordnet und mit diesem im
/// Austausch, etwa wenn es darum geht, welche Mitarbeiter ins Gefecht gehen
/// (siehe: `doc/rules/team_rules.md`).
///
/// Dieses Objekt ist ein Singleton, da es nur ein Restaurant pro Spieler gibt.
class ObjectProfile {
  static final ObjectProfile _instance = ObjectProfile._internal();

  /// Gibt die einzige Instanz des Restaurant-Profils zurück.
  factory ObjectProfile() => _instance;

  ObjectProfile._internal();

  /// Eindeutige ID des Restaurant-Profils (aus [ProfileData]).
  int id = 0;

  /// Name des Spieler-Charakters (der Restaurantbesitzer).
  String name = '';

  /// Name des Restaurants.
  String restaurantName = '';

  /// Aktuelles Budget in Euro.
  int budget = 10000;

  /// Pfad zum Profilbild (optional).
  String? profileImagePath;

  /// Ob ein benutzerdefiniertes Bild geladen wurde.
  bool hasCustomImage = false;

  /// Startbudget (wird zu Spielbeginn festgelegt).
  static const int startBudget = 10000;

  /// Maximale Negativgrenze (doppelter Startwert).
  static const int negativeLimit = -20000;

  /// Referenz auf den [ObjectPlayer] für den Gefechts-Austausch.
  ObjectPlayer _player = ObjectPlayer();

  /// Setzt die [ObjectPlayer]-Instanz, mit der dieses Profil arbeitet.
  void setPlayer(ObjectPlayer player) {
    _player = player;
  }

  /// Gibt die verknüpfte [ObjectPlayer]-Instanz zurück.
  ObjectPlayer get player => _player;

  /// Liste aller angestellten Charaktere (Lehrlinge und höhere Klassen).
  final List<ObjectApprentice> _personal = [];

  /// Gibt die Liste aller angestellten Charaktere zurück.
  List<ObjectApprentice> get personal => List.unmodifiable(_personal);

  /// Gibt die Anzahl der angestellten Charaktere zurück.
  int get personalCount => _personal.length;

  /// Heuert einen neuen [ObjectApprentice] (Lehrling) an und zieht die
  /// Kosten vom Budget ab.
  ///
  /// Gibt `true` zurück, wenn die Anheuerung erfolgreich war, andernfalls
  /// `false` (z. B. bei unzureichendem Budget trotz Negativgrenze).
  bool hireApprentice({int cost = 100}) {
    if (budget - cost < negativeLimit) {
      return false; // Negativgrenze würde überschritten
    }
    budget -= cost;
    final apprentice = ObjectApprentice();
    _personal.add(apprentice);
    return true;
  }

  /// Entlässt einen Charakter unwiderruflich aus dem Team.
  ///
  /// Es gibt keine Rückerstattung des Anheuerungspreises.
  void fireCharacter(ObjectApprentice character) {
    _personal.remove(character);
  }

  /// Bildet einen Lehrling zu einem [ObjectLineCook] fort, sofern er
  /// Level 5 oder höher erreicht hat.
  ///
  /// Die Fortbildung kostet Geld (deutlich teurer als Neuanheuerung).
  /// Gibt `true` bei Erfolg zurück, `false` bei zu niedrigem Level oder
  /// unzureichendem Budget.
  bool upgradeToLineCook(ObjectApprentice apprentice, {int cost = 500}) {
    if (apprentice.levelValue < 5) {
      return false; // Fortbildung erst ab Level 5 möglich
    }
    if (budget - cost < negativeLimit) {
      return false; // Budget reicht nicht
    }
    budget -= cost;

    // Bestehende Werte des Lehrlings merken
    final int currentLevel = apprentice.levelValue;
    final int currentXP = apprentice.currentXPValue;
    final int currentWound = apprentice.woundValue;

    // Alten Lehrling entfernen und durch Line Cook ersetzen
    _personal.remove(apprentice);
    final lineCook = ObjectLineCook();
    lineCook.levelValue = currentLevel;
    lineCook.currentXPValue = currentXP;
    lineCook.woundValue = currentWound;
    _personal.add(lineCook);
    return true;
  }

  /// Wählt die Charaktere aus, die ins Gefecht gehen sollen.
  ///
  /// Gibt eine Liste der ausgewählten Charaktere zurück.
  /// Charaktere im Status `CharacterStatus.dying` werden automatisch
  /// ausgeschlossen.
  List<ObjectApprentice> selectTeamForBattle(List<ObjectApprentice> selected) {
    // Nur einsatzbereite Charaktere erlauben
    final validSelection =
        selected.where((c) => c.status != CharacterStatus.dying).toList();

    // Teammitglieder an ObjectPlayer übergeben
    _player.unitList.clear();
    for (final character in validSelection) {
      _player.unitList.add(character);
    }
    return validSelection;
  }

  /// Überprüft, ob das Budget die Negativgrenze überschritten hat.
  ///
  /// Wenn ja, wird das Restaurant aufgelöst und das Spiel endet dauerhaft.
  bool get isBankrupt => budget < negativeLimit;

  /// Berechnet Negativzinsen, falls das Budget negativ ist.
  ///
  /// Soll nach jedem Gefecht aufgerufen werden.
  void applyNegativeInterest() {
    if (budget >= 0) return;
    // Negativzinsen: 10 % des negativen Betrags
    final interest = (budget.abs() * 0.1).ceil();
    budget -= interest;
  }

  /// Setzt das Restaurant für einen Neustand zurück.
  void reset() {
    id = 0;
    name = '';
    restaurantName = '';
    budget = startBudget;
    profileImagePath = null;
    hasCustomImage = false;
    _personal.clear();
    _player = ObjectPlayer();
  }

  // ── Persistenz ─────────────────────────────────────────────────────────

  /// Lädt die Daten aus einem [ProfileData] in dieses Singleton.
  void loadFromData(ProfileData data) {
    id = data.id;
    name = data.name;
    restaurantName = data.restaurants.isNotEmpty
        ? data.restaurants.first.name
        : '';
    budget = data.budget;
    profileImagePath = data.profileImagePath;
    hasCustomImage = data.profileImagePath != null;

    // Personal wiederherstellen
    _personal.clear();
    for (final sd in data.staff) {
      final character = _staffDataToApprentice(sd);
      if (character != null) {
        _personal.add(character);
      }
    }
  }

  /// Erzeugt aus diesem Singleton ein [ProfileData] zum Speichern.
  ProfileData toProfileData() => ProfileData(
        id: id,
        name: name,
        creationDate: DateTime.now(),
        budget: budget,
        profileImagePath: profileImagePath,
        staff: _personal.map(_apprenticeToStaffData).toList(),
        restaurants: restaurantName.isNotEmpty
            ? [RestaurantData(name: restaurantName)]
            : [],
      );

  /// Speichert den aktuellen Zustand asynchron in den ProfileStorage.
  Future<bool> saveToStorage() async {
    final data = toProfileData();
    return ProfileStorage.saveProfile(data);
  }

  /// Lädt asynchron ein Profil aus dem ProfileStorage und initialisiert
  /// dieses Singleton damit.
  Future<bool> loadFromStorage(int profileId) async {
    final profiles = await ProfileStorage.loadAllProfiles();
    final data = profiles.cast<ProfileData?>().firstWhere(
          (p) => p!.id == profileId,
          orElse: () => null,
        );
    if (data == null) return false;
    loadFromData(data);
    return true;
  }

  // ── Konvertierungshilfen ───────────────────────────────────────────────

  static StaffData _apprenticeToStaffData(ObjectApprentice a) => StaffData(
        name: a.name,
        imagePath: a.imagePath,
        type: a is ObjectLineCook ? 'line_cook' : 'apprentice',
        levelValue: a.levelValue,
        currentXPValue: a.currentXPValue,
        woundValue: a.woundValue,
        attackValue: a.attackValue,
        defenseValue: a.defenseValue,
        movementValue: a.movementValue,
        damageValue: a.damageValue,
        rangeValue: a.rangeValue,
        moneyValue: a.moneyValue,
        xpValue: a.xpValue,
        status: a.status.name,
      );

  static ObjectApprentice? _staffDataToApprentice(StaffData sd) {
    if (sd.type == 'line_cook') {
      return _buildApprentice<ObjectLineCook>(sd, ObjectLineCook());
    } else if (sd.type == 'apprentice') {
      return _buildApprentice<ObjectApprentice>(sd, ObjectApprentice(
        name: sd.name,
        imagePath: sd.imagePath,
        attackValue: sd.attackValue,
        defenseValue: sd.defenseValue,
        movementValue: sd.movementValue,
        damageValue: sd.damageValue,
        rangeValue: sd.rangeValue,
        moneyValue: sd.moneyValue,
        xpValue: sd.xpValue,
      ));
    }
    return null;
  }

  /// Wendet die modifizierbaren Felder aus [StaffData] auf [apprentice] an.
  /// [name] und [imagePath] sind jetzt nicht mehr `final`, daher können wir
  /// auch beim [ObjectLineCook] nachträglich die gespeicherten Werte setzen.
  static T _buildApprentice<T extends ObjectApprentice>(
      StaffData sd, T apprentice) {
    apprentice.name = sd.name;
    apprentice.imagePath = sd.imagePath;
    apprentice.levelValue = sd.levelValue;
    apprentice.currentXPValue = sd.currentXPValue;
    apprentice.woundValue = sd.woundValue;
    apprentice.attackValue = sd.attackValue;
    apprentice.defenseValue = sd.defenseValue;
    apprentice.movementValue = sd.movementValue;
    apprentice.damageValue = sd.damageValue;
    apprentice.rangeValue = sd.rangeValue;
    apprentice.moneyValue = sd.moneyValue;
    apprentice.xpValue = sd.xpValue;
    apprentice.status = CharacterStatus.values.firstWhere(
      (e) => e.name == sd.status,
      orElse: () => CharacterStatus.ready,
    );
    return apprentice;
  }
}