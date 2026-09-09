import 'dart:math';

import 'package:tiled_warfare/models/match_record.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/objects/object_player.dart';
import 'package:tiled_warfare/objects/object_host.dart';
import 'package:tiled_warfare/objects/object_team_medic.dart';
import 'package:tiled_warfare/objects/player_objects/object_apprentice.dart';
import 'package:tiled_warfare/objects/player_objects/object_line_cook.dart';
import 'package:tiled_warfare/services/profile_storage.dart';
import 'package:tiled_warfare/utils/crc32.dart';

/// Verwaltet das Restaurant und alle Dinge, die ausserhalb des Gefechts
/// stattfinden (Teamverwaltung, Budget, Anheuerung etc.).
///
/// Dieses Objekt ist dem [ObjectPlayer] übergeordnet und mit diesem im
/// Austausch, etwa wenn es darum geht, welche Mitarbeiter ins Gefecht gehen
/// (siehe: `doc/rules/team_rules.md`).
///
/// This is a singleton that only holds the state of the *active* restaurant
/// (savegame). A profile may own several restaurants; each of them is an
/// independent savegame with its own budget, team and medics (V1).
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
  int budget = kDefaultRestaurantBudget;

  /// Pfad zum Profilbild (optional).
  String? profileImagePath;

  /// Pfad zum Restaurant-Logo (optional). Wird separat gespeichert.
  String? restaurantLogoPath;

  /// Ob ein benutzerdefiniertes Bild geladen wurde.
  bool hasCustomImage = false;

  /// Id of the currently active restaurant (savegame). `-1` = none loaded.
  int activeRestaurantId = -1;

  /// District of the active restaurant (location from `theworld.tmx`).
  String? activeDistrict;

  /// Full profile data from the last load - basis for the merge in
  /// [toProfileData] (all other savegames stay untouched while saving).
  ProfileData? _profileData;

  /// Returns the profile data taken over on the last load.
  ProfileData? get profileData => _profileData;

  /// Returns the profile's restaurants (state from the last load).
  List<RestaurantData> get profileRestaurants =>
      _profileData?.restaurants ?? const [];

  /// Startbudget (wird zu Spielbeginn festgelegt).
  static const int startBudget = kDefaultRestaurantBudget;

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

  /// Liste aller angestellten Teamärzte.
  final List<ObjectTeamMedic> _hiredMedics = [];

  /// Gibt die Liste aller angestellten Teamärzte zurück.
  List<ObjectTeamMedic> get hiredMedics => List.unmodifiable(_hiredMedics);

  /// Gibt die Anzahl der angestellten Teamärzte zurück.
  int get hiredMedicsCount => _hiredMedics.length;

  /// Stellt einen Teamarzt ein.
  void hireMedic(ObjectTeamMedic medic) {
    _hiredMedics.add(medic);
  }

  /// Entlässt einen Teamarzt.
  void fireMedic(ObjectTeamMedic medic) {
    _hiredMedics.remove(medic);
  }

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
  ///
  /// Speichert außerdem die vollständige Auswahl in
  /// [ObjectPlayer.battleRoster], damit der Ergebnis-Bildschirm auch
  /// gefallene Einheiten korrekt auflisten kann.
  List<ObjectApprentice> selectTeamForBattle(List<ObjectApprentice> selected) {
    // Nur einsatzbereite Charaktere erlauben
    final validSelection =
        selected.where((c) => c.status != CharacterStatus.dying).toList();

    // Teammitglieder an ObjectPlayer übergeben
    _player.unitList.clear();
    for (final character in validSelection) {
      _player.unitList.add(character);
    }

    // Vollständigen Schlachtzug (inkl. später gefallener) sichern
    _player.battleRoster = List<ObjectApprentice>.from(validSelection);

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

  /// Führt für alle Einheiten, die im Gefecht gefallen sind (`woundValue ≤ 0`),
  /// einen Rettungswurf (W100) durch und aktualisiert den [CharacterStatus].
  ///
  /// Gemäß team_rules.md Abschnitt 4.2 und 4.5:
  /// - Basis-Zielwert: 50
  /// - +10 pro Level des Charakters
  /// - +5 pro defenseValue über 30
  /// - −10 bei übermäßigem Schaden (overkilled)
  /// - Zusätzlich: [ObjectTeamMedic.effectiveSurvivalBonus], falls ein Arzt angestellt ist
  ///
  /// Einmal gescheiterte Würfe können gegen Bezahlung wiederholt werden,
  /// wenn ein Teamarzt verfügbar ist.
  void _performSurvivalRolls() {
    final random = Random();
    final hasMedic = _hiredMedics.isNotEmpty;
    final medicBonus = hasMedic
        ? _hiredMedics.map((m) => m.effectiveSurvivalBonus).reduce(
            (a, b) => a > b ? a : b)
        : 0;

    for (final unit in _personal.toList()) {
      if (unit.woundValue > 0) continue; // Einheit lebt noch

      // Zielwert berechnen
      int targetValue = 50; // Basis
      targetValue += unit.levelValue * 10; // +10 pro Level
      if (unit.defenseValue > 30) {
        targetValue += (unit.defenseValue - 30) * 5; // +5 pro Punkt über 30
      }
      // −10 bei übermäßigem Schaden (Verlust von mehr als woundValue)
      // Vereinfacht: wenn die Einheit durch `overkilled`-Schaden starb
      if (unit.status == CharacterStatus.overkilled) {
        targetValue -= 10;
      }
      targetValue += medicBonus; // Teamarzt-Bonus

      // Erster Rettungswurf
      int roll = random.nextInt(100) + 1;
      if (roll <= targetValue.clamp(1, 100)) {
        // Gerettet! Verletzungsstatus setzen (nicht tot)
        unit.woundValue = 1; // Minimal überleben
        unit.status = CharacterStatus.dying;
        continue;
      }

      // Bei Misserfolg und vorhandenem Teamarzt: Wiederholung gegen Bezahlung
      if (hasMedic && budget >= 200) {
        budget -= 200; // Kosten für Wiederbelebung
        roll = random.nextInt(100) + 1;
        if (roll <= targetValue.clamp(1, 100)) {
          unit.woundValue = 1;
          unit.status = CharacterStatus.dying;
          continue;
        }
      }

      // Endgültig tot
      unit.status = CharacterStatus.dead;
    }

    // Tote Einheiten aus dem Personal entfernen
    _personal.removeWhere((unit) => unit.status == CharacterStatus.dead);
  }

  /// Fügt für alle angestellten Charaktere einen Match-Record hinzu.
  ///
  /// Diese Methode wird nach jedem Gefecht aufgerufen, um die Match-Historie
  /// der Charaktere zu aktualisieren. Jeder Charakter erhält einen Eintrag
  /// mit dem Ergebnis des Gefechts.
  ///
  /// [opponentName] ist der Name des Gegners (z. B. "Street Battle").
  /// [result] ist das Ergebnis des Matches (Sieg/Niederlage/Unentschieden).
  /// [kills] und [deaths] sind optionale Maps von Charakternamen zu
  /// Kill/Death-Zahlen (falls verfügbar).
  void addMatchRecordsForBattle({
    required String opponentName,
    required MatchResult result,
    Map<String, int>? kills,
    Map<String, int>? deaths,
  }) {
    for (final character in _personal) {
      character.matchHistory.add(MatchRecord(
        date: DateTime.now(),
        opponentName: opponentName,
        result: result,
        kills: kills?[character.name] ?? 0,
        deaths: deaths?[character.name] ?? 0,
      ));
    }
  }

  /// Synchronisiert die überlebenden Einheiten nach einem Gefecht mit dem Personal.
  ///
  /// Führt für gefallene Einheiten ([CharacterStatus]) Rettungswürfe gemäß
  /// team_rules.md Abschnitt 4.2 durch. Überlebende Einheiten erhalten ihre
  /// Kampfwerte zurück. Tote Einheiten werden endgültig entfernt.
  ///
  /// [survivors] sind die Einheiten, die das Gefecht überlebt haben
  /// (woundValue > 0). Einheiten in [_personal], die nicht in [survivors]
  /// enthalten sind, gelten als gefallen und durchlaufen den Rettungswurf.
  void syncUnitsAfterBattle(List<ObjectApprentice> survivors) {
    // Zuerst: existierende Einträge aus [_personal] mit den Überlebenden
    // aus dem Gefecht aktualisieren.
    // Vergleich über Identität statt name, da Namensgleichheit zu
    // fehlerhaften Aktualisierungen führen kann.
    for (final survivor in survivors) {
      final index = _personal.indexWhere((p) => identical(p, survivor));
      if (index >= 0) {
        _personal[index] = survivor;
      }
    }

    // Rettungswürfe für alle Einheiten mit woundValue ≤ 0 durchführen
    _performSurvivalRolls();
  }

  /// Resets to a fresh restaurant savegame (restaurant restart).
  ///
  /// V1-fixed semantics (the surrounding flow is steered by V2): the profile is
  /// kept; the currently active restaurant - if any - is marked as dissolved
  /// (unless [markCurrentDissolved] is false) and a brand-new savegame (new id,
  /// default name, [startBudget], empty team/medics) is created in [district].
  /// All other savegames of the profile stay untouched.
  void reset({String? district, bool markCurrentDissolved = true}) {
    // Mark the currently active restaurant as dissolved.
    if (markCurrentDissolved &&
        _profileData != null &&
        activeRestaurantId > 0) {
      final index = _profileData!.restaurants
          .indexWhere((r) => r.id == activeRestaurantId);
      if (index >= 0) {
        final current = _profileData!.restaurants[index];
        current.isDissolved = true;
        current.dissolvedAt = DateTime.now();
      }
    }

    final newId = CRC32.compute(
        '${restaurantName.isEmpty ? 'Neues Restaurant' : restaurantName}'
        '${DateTime.now().microsecondsSinceEpoch}');
    activeRestaurantId = newId;
    activeDistrict = district;
    restaurantName = 'Neues Restaurant';
    restaurantLogoPath = null;
    budget = startBudget;
    hasCustomImage = false;
    _personal.clear();
    _hiredMedics.clear();
    _player = ObjectPlayer();
  }

  // ── Persistenz ─────────────────────────────────────────────────────────

  /// Loads the data from a [ProfileData] into this singleton.
  ///
  /// Loads only the state of the savegame [restaurantId] (fallback: the active
  /// restaurant, then the first entry). All state fields (name, logo, budget,
  /// team, medics) refer exclusively to this restaurant. The [data] reference
  /// is kept for the merge performed on save.
  void loadFromData(ProfileData data, {int? restaurantId}) {
    _profileData = data;
    id = data.id;
    name = data.name;
    profileImagePath = data.profileImagePath;
    hasCustomImage = data.profileImagePath != null;

    final restaurant = _resolveRestaurant(data, restaurantId);
    if (restaurant == null) {
      activeRestaurantId = -1;
      activeDistrict = null;
      restaurantName = '';
      restaurantLogoPath = null;
      budget = startBudget;
      _personal.clear();
      _hiredMedics.clear();
      return;
    }

    activeRestaurantId = restaurant.id;
    activeDistrict = restaurant.district;
    restaurantName = restaurant.name;
    restaurantLogoPath = restaurant.logoPath;
    budget = restaurant.budget;

    // Restore team.
    _personal.clear();
    for (final sd in restaurant.staff) {
      final character = _staffDataToApprentice(sd);
      if (character != null) {
        _personal.add(character);
      }
    }

    // Restore team medics.
    _hiredMedics.clear();
    for (final md in restaurant.medics) {
      final medic = _medicDataToTeamMedic(md);
      if (medic != null) {
        _hiredMedics.add(medic);
      }
    }
  }

  /// Looks up the savegame inside [data] - first by [restaurantId], then by
  /// the active restaurant, finally by the first entry.
  RestaurantData? _resolveRestaurant(ProfileData data, int? restaurantId) {
    final wanted = <int>{};
    if (restaurantId != null) wanted.add(restaurantId);
    if (activeRestaurantId > 0) wanted.add(activeRestaurantId);
    for (final candidate in wanted) {
      final match = data.restaurants.cast<RestaurantData?>().firstWhere(
            (r) => r!.id == candidate,
            orElse: () => null,
          );
      if (match != null) return match;
    }
    return data.restaurants.isNotEmpty ? data.restaurants.first : null;
  }

  /// Builds a [ProfileData] for saving from this singleton.
  ///
  /// Merging (V1): only the *active* restaurant is written back into its slot
  /// of the profile's `restaurants` list; all other savegames are kept
  /// untouched. `lastSeenAt` is refreshed; the slot's `isDissolved`/
  /// `dissolvedAt` are preserved. A freshly founded restaurant (no slot yet) is
  /// appended and [activeRestaurantId] is set.
  ProfileData toProfileData() {
    var activeId = activeRestaurantId;
    if (activeId <= 0 && restaurantName.isNotEmpty) {
      activeId = CRC32.compute(
          '$restaurantName${DateTime.now().toIso8601String()}');
    }

    final restaurants = _profileData != null
        ? List<RestaurantData>.from(_profileData!.restaurants)
        : <RestaurantData>[];
    final existingIndex = restaurants.indexWhere((r) => r.id == activeId);

    final active = RestaurantData(
      id: activeId,
      name: restaurantName,
      logoPath: restaurantLogoPath,
      district: activeDistrict,
      budget: budget,
      staff: _personal.map(_apprenticeToStaffData).toList(),
      medics: _hiredMedics.map(_medicToMedicData).toList(),
      lastSeenAt: DateTime.now(),
      isDissolved: existingIndex >= 0
          ? restaurants[existingIndex].isDissolved
          : false,
      dissolvedAt: existingIndex >= 0
          ? restaurants[existingIndex].dissolvedAt
          : null,
    );

    if (existingIndex >= 0) {
      restaurants[existingIndex] = active;
    } else if (restaurantName.isNotEmpty) {
      restaurants.add(active);
      activeRestaurantId = activeId;
    }

    return ProfileData(
      id: id,
      name: name,
      creationDate: _profileData?.creationDate ?? DateTime.now(),
      profileImagePath: profileImagePath,
      restaurants: restaurants,
    );
  }

  /// Speichert den aktuellen Zustand asynchron in den ProfileStorage.
  Future<bool> saveToStorage() async {
    final data = toProfileData();
    return ProfileStorage.saveProfile(data);
  }

  /// Lädt asynchron ein Profil aus dem ProfileStorage und initialisiert
  /// dieses Singleton damit.
  Future<bool> loadFromStorage(int profileId, {int? restaurantId}) async {
    final profiles = await ProfileStorage.loadAllProfiles();
    final data = profiles.cast<ProfileData?>().firstWhere(
          (p) => p!.id == profileId,
          orElse: () => null,
        );
    if (data == null) return false;
    loadFromData(data, restaurantId: restaurantId);
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
        matchHistory: a.matchHistory.map((m) => m.toJson()).toList(),
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
    // Match-Historie wiederherstellen
    apprentice.matchHistory = sd.matchHistory
        .map((m) => MatchRecord.fromJson(m))
        .toList();
    return apprentice;
  }

  /// Konvertiert einen [ObjectTeamMedic] in [MedicData] für die Serialisierung.
  static MedicData _medicToMedicData(ObjectTeamMedic m) => MedicData(
        id: m.id,
        name: m.name,
        quality: m.quality.name,
        costPerWeek: m.costPerWeek,
        enneagramProfileName: m.enneagramProfile.name,
      );

  /// Konvertiert [MedicData] zurück in einen [ObjectTeamMedic].
  /// Da die Felder von [ObjectTeamMedic] jetzt nicht mehr final sind,
  /// können wir sie nachträglich setzen.
  static ObjectTeamMedic? _medicDataToTeamMedic(MedicData md) {
    final medic = ObjectTeamMedic();
    medic.id = md.id;
    medic.name = md.name;
    medic.quality = MedicQuality.values.firstWhere(
      (q) => q.name == md.quality,
      orElse: () => MedicQuality.niedrig,
    );
    medic.costPerWeek = md.costPerWeek;
    medic.enneagramProfile = EnneagramProfile.all.firstWhere(
      (p) => p.name == md.enneagramProfileName,
      orElse: () => EnneagramProfile.all.first,
    );
    return medic;
  }
}