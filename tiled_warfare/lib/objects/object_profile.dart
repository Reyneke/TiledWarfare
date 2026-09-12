import 'dart:math';

import 'package:tiled_warfare/models/cuisine.dart';
import 'package:tiled_warfare/models/match_record.dart';
import 'package:tiled_warfare/models/restaurant_upgrade.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/objects/object_player.dart';
import 'package:tiled_warfare/objects/object_host.dart';
import 'package:tiled_warfare/objects/object_team_medic.dart';
import 'package:tiled_warfare/objects/player_objects/object_apprentice.dart';
import 'package:tiled_warfare/objects/player_objects/object_line_cook.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/economy_service.dart';
import 'package:tiled_warfare/services/game_clock_service.dart';
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

  /// Ergebnis des jüngsten Gefechts (Quelle für den `resultBonus` des
  /// passiven Einkommens, § 8).
  MatchResult? lastMatchResult;

  /// Anker des Echtzeit-Zeitsystems (V8) für den aktiven Spielstand – Basis
  /// für den Countdown bis zur nächsten Wochenabbuchung.
  DateTime? lastSeenAt;

  /// Küche (Konzept) des aktiven Restaurants (§ 9).
  Cuisine activeCuisine = Cuisine.italian;

  /// Bis wann der Rebranding-Attraktivitätsmalus gilt (§ 9).
  DateTime? rebrandingPenaltyUntil;

  /// Ausbaustufen der Restaurant-Erweiterungen (§ 10); fehlender Key = Stufe 0.
  Map<UpgradeType, int> activeUpgrades = {};

  /// Full profile data from the last load - basis for the merge in
  /// [toProfileData] (all other savegames stay untouched while saving).
  ProfileData? _profileData;

  /// Returns the profile data taken over on the last load.
  ProfileData? get profileData => _profileData;

  /// Returns the profile's restaurants (state from the last load).
  List<RestaurantData> get profileRestaurants =>
      _profileData?.restaurants ?? const [];

  /// Startbudget (wird zu Spielbeginn festgelegt, V7).
  static const int startBudget = EconomyBalance.startBudget;

  /// Maximale Negativgrenze (doppelter Startwert, V7).
  static const int negativeLimit = EconomyBalance.negativeLimit;

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
  ///
  /// Die Wochenkosten werden aus Qualität und **aktueller Teamgröße** neu
  /// berechnet (§ 4.5). Die erste Abbuchung erfolgt erst zum nächsten
  /// Wochen-Tick (kein anteiliger Einzug).
  void hireMedic(ObjectTeamMedic medic) {
    medic.costPerWeek =
        EconomyService.weeklyMedicCost(medic.quality, personalCount);
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
  bool hireApprentice({int cost = EconomyBalance.hireApprenticeCost}) {
    if (budget - cost < negativeLimit) {
      return false; // Negativgrenze würde überschritten
    }
    budget -= cost;
    // Küche bestimmt Namensstamm und Token-Grafik (§ 9).
    final apprentice = ObjectApprentice(cuisine: activeCuisine);
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
  bool upgradeToLineCook(ObjectApprentice apprentice,
      {int cost = EconomyBalance.upgradeToLineCookCost}) {
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
    final CharacterStatus currentStatus = apprentice.status;
    final DateTime? currentInjury = apprentice.injuryStartedAt;
    final CharacterStatus? currentInjuryStart = apprentice.injuryStartStatus;
    final DateTime? currentShot = apprentice.emergencyShotAt;
    final CharacterStatus? currentSuppressed = apprentice.suppressedStatus;

    // Alten Lehrling entfernen und durch Line Cook ersetzen
    _personal.remove(apprentice);
    // Küche bestimmt Namensstamm und Token-Grafik (§ 9).
    final lineCook = ObjectLineCook(cuisine: activeCuisine);
    lineCook.levelValue = currentLevel;
    lineCook.currentXPValue = currentXP;
    lineCook.woundValue = currentWound;
    lineCook.status = currentStatus;
    lineCook.injuryStartedAt = currentInjury;
    lineCook.injuryStartStatus = currentInjuryStart;
    lineCook.emergencyShotAt = currentShot;
    lineCook.suppressedStatus = currentSuppressed;
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

    // Teammitglieder an ObjectPlayer übergeben. Die Trefferpunkte werden beim
    // Gefechtsstart konsistent aus dem Management-Status abgeleitet (V3): eine
    // Quelle der Wahrheit, damit ein `ready`-Charakter voll einsatzfähig startet.
    _player.unitList.clear();
    for (final character in validSelection) {
      character.woundValue = GameClockService.woundValueFor(character.status);
      _player.unitList.add(character);
    }

    // Vollständigen Schlachtzug (inkl. später gefallener) sichern
    _player.battleRoster = List<ObjectApprentice>.from(validSelection);

    return validSelection;
  }

  /// Überprüft, ob das Budget die Negativgrenze überschritten hat.
  ///
  /// Wenn ja, wird das Restaurant aufgelöst und das Spiel endet dauerhaft.
  bool get isBankrupt => EconomyService.isBankrupt(budget);

  /// Berechnet Negativzinsen, falls das Budget negativ ist (§ 2.2).
  ///
  /// Wird nach jedem Gefecht aufgerufen.
  void applyNegativeInterest() {
    budget = EconomyService.applyNegativeInterest(budget);
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

      // Zielwert berechnen (Werte aus EconomyBalance, V7).
      int targetValue = EconomyBalance.survivalBase;
      targetValue += unit.levelValue * EconomyBalance.survivalPerLevel;
      if (unit.defenseValue > EconomyBalance.survivalDefenseThreshold) {
        targetValue += (unit.defenseValue -
                EconomyBalance.survivalDefenseThreshold) *
            EconomyBalance.survivalPerDefenseOverThreshold;
      }
      // Strafe bei übermäßigem Schaden (overkilled).
      if (unit.status == CharacterStatus.overkilled) {
        targetValue -= EconomyBalance.survivalOverkillPenalty;
      }
      targetValue += medicBonus; // Teamarzt-Bonus

      // Erster Rettungswurf
      int roll = random.nextInt(100) + 1;
      if (roll <= targetValue.clamp(1, 100)) {
        // Gerettet! Verletzungsstatus setzen (nicht tot).
        // V3: `injuryStartedAt` ist der Anker der Echtzeit-Heilung; alte
        // Spritzen-Marker werden verworfen (neue Verletzung).
        unit.injuryStartedAt = DateTime.now();
        unit.injuryStartStatus = CharacterStatus.dying;
        unit.emergencyShotAt = null;
        unit.suppressedStatus = null;
        unit.status = CharacterStatus.dying;
        continue;
      }

      // Bei Misserfolg und vorhandenem Teamarzt: Wiederholung gegen Bezahlung
      if (hasMedic && budget >= EconomyBalance.revivalCost) {
        budget -= EconomyBalance.revivalCost; // Kosten für Wiederbelebung
        roll = random.nextInt(100) + 1;
        if (roll <= targetValue.clamp(1, 100)) {
          unit.injuryStartedAt = DateTime.now();
          unit.injuryStartStatus = CharacterStatus.dying;
          unit.emergencyShotAt = null;
          unit.suppressedStatus = null;
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

    // V3: Unmittelbar nach dem Rettungswurf erhält jeder `dying`-Charakter
    // automatisch die Notfall-Spritze – sofern ein Teamarzt angestellt ist und
    // das Budget die Kosten trägt. Der Rückfall läuft im Zeit-Tick.
    _applyAutomaticEmergencyShots();
  }

  /// Verabreicht allen `dying`-Charakteren automatisch die Notfall-Spritze (V3).
  ///
  /// Bucht [EconomyBalance.emergencyShotCost] vom Budget ab, merkt sich den
  /// unterdrückten Status ([ObjectApprentice.suppressedStatus]) und setzt den
  /// Charakter vorläufig auf `ready`. Ohne Teamarzt oder bei zu geringem Budget
  /// passiert nichts (die Verletzung bleibt bestehen).
  void _applyAutomaticEmergencyShots({DateTime? now}) {
    if (_hiredMedics.isEmpty) return;
    final shotAt = now ?? DateTime.now();
    for (final character in _personal) {
      if (character.status != CharacterStatus.dying) continue;
      if (budget - EconomyBalance.emergencyShotCost < negativeLimit) continue;
      budget -= EconomyBalance.emergencyShotCost;
      character.suppressedStatus = character.status;
      character.injuryStartStatus ??= character.status;
      character.emergencyShotAt = shotAt;
      character.injuryStartedAt ??= shotAt;
      character.status = CharacterStatus.ready;
    }
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
    lastMatchResult = null;
    lastSeenAt = DateTime.now();
    activeCuisine = Cuisine.italian;
    rebrandingPenaltyUntil = null;
    activeUpgrades = {};
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
      lastMatchResult = null;
      lastSeenAt = null;
      activeCuisine = Cuisine.italian;
      rebrandingPenaltyUntil = null;
      activeUpgrades = {};
      _personal.clear();
      _hiredMedics.clear();
      return;
    }

    activeRestaurantId = restaurant.id;
    activeDistrict = restaurant.district;
    restaurantName = restaurant.name;
    restaurantLogoPath = restaurant.logoPath;
    budget = restaurant.budget;
    lastMatchResult = restaurant.lastMatchResult;
    lastSeenAt = restaurant.lastSeenAt;
    activeCuisine = restaurant.cuisine;
    rebrandingPenaltyUntil = restaurant.rebrandingPenaltyUntil;
    activeUpgrades = Map.of(restaurant.upgrades);

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
      cuisine: activeCuisine,
      rebrandingPenaltyUntil: rebrandingPenaltyUntil,
      budget: budget,
      staff: _personal.map(_apprenticeToStaffData).toList(),
      medics: _hiredMedics.map(_medicToMedicData).toList(),
      upgrades: Map.of(activeUpgrades),
      // V3/V8: den (ggf. durch den Catch-up fortgeschriebenen) Zeitanker
      // persistieren, damit verpasste Zeit nicht erneut abgerechnet wird.
      lastSeenAt: lastSeenAt ??
          (existingIndex >= 0 ? restaurants[existingIndex].lastSeenAt : null) ??
          DateTime.now(),
      lastMatchResult: lastMatchResult,
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

  /// Liefert einen Snapshot des aktiven Restaurants (ohne zu speichern) –
  /// für Ableitungen wie Countdown und passives Einkommen in der UI.
  RestaurantData activeRestaurantSnapshot() => RestaurantData(
        id: activeRestaurantId,
        name: restaurantName,
        logoPath: restaurantLogoPath,
        district: activeDistrict,
        cuisine: activeCuisine,
        rebrandingPenaltyUntil: rebrandingPenaltyUntil,
        budget: budget,
        staff: _personal.map(_apprenticeToStaffData).toList(),
        medics: _hiredMedics.map(_medicToMedicData).toList(),
        upgrades: Map.of(activeUpgrades),
        lastSeenAt: lastSeenAt,
        lastMatchResult: lastMatchResult,
      );

  // ── Erweiterungen (§ 10) ──────────────────────────────────────────────

  /// Aktuelle Ausbaustufe einer Erweiterung (0 = nicht gebaut).
  int upgradeLevel(UpgradeType type) => activeUpgrades[type] ?? 0;

  /// Baut [type] eine Stufe aus (kostet `Ankauf-Basis × neue Stufe`).
  ///
  /// Gibt `false` zurück, wenn die Maximalstufe erreicht ist oder das Budget
  /// die Negativgrenze überschreiten würde.
  bool buyUpgrade(UpgradeType type) {
    final spec = EconomyBalance.upgrades[type];
    if (spec == null) return false;
    final current = upgradeLevel(type);
    if (current >= spec.maxLevel) return false;
    final cost = EconomyService.upgradeCost(type, current + 1) -
        EconomyService.upgradeCost(type, current);
    if (budget - cost < negativeLimit) return false;
    budget -= cost;
    activeUpgrades[type] = current + 1;
    return true;
  }

  /// Baut [type] eine Stufe zurück (senkt den wöchentlichen Unterhalt, ohne
  /// Erstattung).
  bool downgradeUpgrade(UpgradeType type) {
    final current = upgradeLevel(type);
    if (current <= 0) return false;
    if (current == 1) {
      activeUpgrades.remove(type);
    } else {
      activeUpgrades[type] = current - 1;
    }
    return true;
  }

  /// Verkauft [type] vollständig und erstattet [EconomyService.sellRefund].
  ///
  /// Gibt die Erstattung in Euro zurück (0, wenn nicht gebaut).
  int sellUpgrade(UpgradeType type) {
    final current = upgradeLevel(type);
    if (current <= 0) return 0;
    final refund = EconomyService.sellRefund(type, current);
    budget += refund;
    activeUpgrades.remove(type);
    return refund;
  }

  // ── Echtzeit-Catch-up (V8) ────────────────────────────────────────────

  /// Holt fällige Wochen für das aktive Restaurant nach und schreibt Budget
  /// und Zeitanker zurück. Wird beim Login, beim Restaurant-Wechsel und beim
  /// Wiederaufnehmen der App (App-Resume) aufgerufen.
  WeeklyTickResult runCatchUp(DateTime now) {
    final snapshot = activeRestaurantSnapshot();
    final result = GameClockService.catchUp(snapshot, now);
    budget = snapshot.budget;
    lastSeenAt = snapshot.lastSeenAt;
    // V3: geheilten Status/Spritzen-Zustand in die In-Memory-Charaktere
    // zurückschreiben (beide Listen sind 1:1 über die Konvertierung geordnet).
    _syncStaffFromSnapshot(snapshot);
    return result;
  }

  /// Schreibt den durch den Catch-up veränderten Heilungs-/Spritzenzustand aus
  /// [snapshot] zurück in die In-Memory-Charaktere (V3).
  void _syncStaffFromSnapshot(RestaurantData snapshot) {
    for (var i = 0; i < _personal.length && i < snapshot.staff.length; i++) {
      final sd = snapshot.staff[i];
      final character = _personal[i];
      character.status = CharacterStatus.values.firstWhere(
        (e) => e.name == sd.status,
        orElse: () => character.status,
      );
      character.injuryStartedAt = sd.injuryStartedAt;
      character.injuryStartStatus = sd.injuryStartStatus == null
          ? null
          : CharacterStatus.values.firstWhere(
              (e) => e.name == sd.injuryStartStatus,
              orElse: () => CharacterStatus.dying,
            );
      character.emergencyShotAt = sd.emergencyShotAt;
      character.suppressedStatus = sd.suppressedStatus == null
          ? null
          : CharacterStatus.values.firstWhere(
              (e) => e.name == sd.suppressedStatus,
              orElse: () => CharacterStatus.dying,
            );
    }
  }

  /// Wechselt die Küche des aktiven Restaurants (Rebranding, § 9).
  ///
  /// Kostet [EconomyBalance.rebrandingCost] und setzt einen zeitlich
  /// begrenzten Attraktivitäts-Malus. Gibt `false` zurück, wenn die Küche
  /// bereits aktiv ist oder das Budget nicht reicht.
  bool rebrandCuisine(Cuisine newCuisine) {
    if (newCuisine == activeCuisine) return false;
    if (budget - EconomyBalance.rebrandingCost < negativeLimit) return false;
    budget -= EconomyBalance.rebrandingCost;
    activeCuisine = newCuisine;
    rebrandingPenaltyUntil = DateTime.now().add(
      const Duration(days: 7 * EconomyBalance.rebrandingPenaltyWeeks),
    );
    return true;
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
        injuryStartedAt: a.injuryStartedAt,
        injuryStartStatus: a.injuryStartStatus?.name,
        emergencyShotAt: a.emergencyShotAt,
        suppressedStatus: a.suppressedStatus?.name,
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
    apprentice.injuryStartedAt = sd.injuryStartedAt;
    apprentice.injuryStartStatus = sd.injuryStartStatus == null
        ? null
        : CharacterStatus.values.firstWhere(
            (e) => e.name == sd.injuryStartStatus,
            orElse: () => CharacterStatus.dying,
          );
    apprentice.emergencyShotAt = sd.emergencyShotAt;
    apprentice.suppressedStatus = sd.suppressedStatus == null
        ? null
        : CharacterStatus.values.firstWhere(
            (e) => e.name == sd.suppressedStatus,
            orElse: () => CharacterStatus.dying,
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