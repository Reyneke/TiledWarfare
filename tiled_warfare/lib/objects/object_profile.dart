import 'dart:math';

import 'package:random_name_generator/random_name_generator.dart';
import 'package:tiled_warfare/models/cuisine.dart';
import 'package:tiled_warfare/models/management_role.dart';
import 'package:tiled_warfare/models/match_record.dart';
import 'package:tiled_warfare/models/personality.dart';
import 'package:tiled_warfare/models/medic_quality.dart';
import 'package:tiled_warfare/models/restaurant_upgrade.dart';
import 'package:tiled_warfare/models/staff_entry.dart';
import 'package:tiled_warfare/models/support_role.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/objects/object_player.dart';
import 'package:tiled_warfare/objects/object_team_medic.dart';
import 'package:tiled_warfare/objects/player_objects/object_apprentice.dart';
import 'package:tiled_warfare/objects/player_objects/object_chef_de_partie.dart';
import 'package:tiled_warfare/objects/player_objects/object_head_chef.dart';
import 'package:tiled_warfare/objects/player_objects/object_line_cook.dart';
import 'package:tiled_warfare/objects/player_objects/object_sous_chef.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/economy_service.dart';
import 'package:tiled_warfare/services/game_clock_service.dart';
import 'package:tiled_warfare/services/profile_storage.dart';
import 'package:tiled_warfare/services/stress_service.dart';
import 'package:tiled_warfare/utils/crc32.dart';

/// Aufgeschobene Änderung an einem **nicht-aktiven** Restaurant (V10).
///
/// Sammelt Personal-Transfers bis zum nächsten [ObjectProfile.toProfileData]:
/// anzuhängende [StaffData] und eine Budget-Änderung (negativ = Kosten).
class _TargetRestaurantEdit {
  final List<StaffData> appendStaff = [];
  int budgetDelta = 0;
}

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

  /// Ob das aktive Restaurant ein eigenes Logo hat – abgeleitet aus
  /// [restaurantLogoPath] statt aus dem Profilbild (V4/P2). Bewusst kein
  /// mutablem Feld, damit der Zustand nicht vom Logo weglaufen kann.
  bool get hasCustomImage =>
      restaurantLogoPath != null && restaurantLogoPath!.isNotEmpty;

  /// Kopf-Bild des aktiven Restaurants: eigenes Logo, sonst die Küchen-Grafik
  /// des Restaurants (§ 9). Einzige Quelle der Wahrheit für die UI (V4).
  String get headerImagePath =>
      hasCustomImage ? restaurantLogoPath! : activeCuisine.tokenImagePath;

  /// Id of the currently active restaurant (savegame). `-1` = none loaded.
  int activeRestaurantId = -1;

  /// District of the active restaurant (location from `theworld.tmx`).
  String? activeDistrict;

  /// Ergebnis des jüngsten Gefechts (Quelle für den `resultBonus` des
  /// passiven Einkommens, § 8).
  MatchResult? lastMatchResult;

  /// Einmalig anzuzeigendes Catch-up-Ergebnis (L2/§ 6).
  ///
  /// Wird beim Login gesetzt, wenn der Catch-up vor dem Aufbau des
  /// Restaurant-Screens läuft; die UI konsumiert und leert es.
  WeeklyTickResult? pendingCatchUpResult;

  /// Anker des Echtzeit-Zeitsystems (V8) für den aktiven Spielstand – bis
  /// hierhin sind alle **vollen Echtzeittage** abgerechnet (Tages-Schritt, § 6).
  DateTime? lastSeenAt;

  /// Beginn des laufenden 7-Tage-Blocks (Wochenanker, § 6) – stabil über
  /// mehrere Catch-ups hinweg; Alt-Stände: Fallback auf [lastSeenAt].
  DateTime? weekAnchorAt;

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

  /// Aufgeschobene Änderungen an **nicht-aktiven** Restaurants (Karrierepfade,
  /// V10). Werden in [toProfileData] auf den jeweiligen Slot angewendet und
  /// danach verworfen. Genutzt vom Personal-Transfer.
  final Map<int, _TargetRestaurantEdit> _pendingTargetEdits = {};

  /// Sucht ein Restaurant des geladenen Profils anhand seiner [restaurantId].
  RestaurantData? _findRestaurant(int restaurantId) {
    final restaurants = _profileData?.restaurants;
    if (restaurants == null) return null;
    for (final restaurant in restaurants) {
      if (restaurant.id == restaurantId) return restaurant;
    }
    return null;
  }

  /// Startbudget (wird zu Spielbeginn festgelegt, V7).
  static const int startBudget = EconomyBalance.startBudget;

  /// Maximale Negativgrenze (doppelter Startwert, V7).
  static const int negativeLimit = EconomyBalance.negativeLimit;

  /// Referenz auf den [ObjectPlayer] für den Gefechts-Austausch.
  ObjectPlayer _player = ObjectPlayer();

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

  /// Angestellte Hilfs-/Service-Rollen (Karrierepfade, V10, Phase 6).
  final List<SupportRoleData> _supportStaff = [];

  /// Gibt die Liste aller angestellten Hilfs-/Service-Rollen zurück.
  List<SupportRoleData> get supportStaff => List.unmodifiable(_supportStaff);

  /// Gibt die Anzahl der angestellten Hilfs-/Service-Rollen zurück.
  int get supportStaffCount => _supportStaff.length;

  /// Generalisiertes Nicht-Kampf-Personal aller Kategorien (Option C, `11a`).
  ///
  /// Spiegelt `RestaurantData.staffEntries`; Küchen-Rollen sind über
  /// [_supportStaff] zusätzlich domänenspezifisch verfügbar.
  final List<StaffEntryData> _staffEntries = [];

  /// Gibt das gesamte angestellte Nicht-Kampf-Personal zurück.
  List<StaffEntryData> get staffEntries => List.unmodifiable(_staffEntries);

  /// Stellt eine Hilfs-/Service-Rolle ein (Karrierepfade, V10, Phase 6).
  ///
  /// Der Wochenlohn stammt aus `EconomyBalance.supportRoleWagePerWeek` und wird
  /// erst zum nächsten Wochen-Tick abgebucht (kein anteiliger Einzug). Gibt die
  /// angestellte Rolle zurück.
  SupportRoleData hireSupportRole(SupportRole role, {DateTime? now}) {
    final hiredAt = now ?? DateTime.now();
    final roleName = RandomNames(activeCuisine.zone).fullName();
    final entry = SupportRoleData(
      id: CRC32.compute('$roleName${hiredAt.toIso8601String()}'),
      name: roleName,
      role: role.name,
      costPerWeek: EconomyBalance.supportRoleWagePerWeek[role] ?? 0,
      hiredAt: hiredAt,
    );
    _supportStaff.add(entry);
    _staffEntries.add(StaffEntryData(
      id: entry.id,
      name: entry.name,
      kind: RoleKind.support,
      role: entry.role,
      costPerWeek: entry.costPerWeek,
      hiredAt: entry.hiredAt,
    ));
    return entry;
  }

  /// Entlässt eine Hilfs-/Service-Rolle (keine Rückerstattung).
  void fireSupportRole(SupportRoleData entry) {
    _supportStaff.remove(entry);
    _staffEntries.removeWhere((e) => e.id == entry.id);
  }

  /// Gibt die angestellten Verwaltungs-/Marketing-Rollen zurück (Option C).
  List<StaffEntryData> get managementStaff => List.unmodifiable(
        _staffEntries.where((e) => e.kind == RoleKind.management),
      );

  /// Stellt eine Verwaltungs-/Marketing-Rolle ein (Option C, `11a`).
  ///
  /// Der Wochenlohn stammt aus `EconomyBalance.managementRoleWagePerWeek` und
  /// wird erst zum nächsten Wochen-Tick abgebucht (kein anteiliger Einzug).
  StaffEntryData hireManagementRole(ManagementRole role, {DateTime? now}) {
    final hiredAt = now ?? DateTime.now();
    final roleName = RandomNames(activeCuisine.zone).fullName();
    final entry = StaffEntryData(
      id: CRC32.compute('$roleName${hiredAt.toIso8601String()}'),
      name: roleName,
      kind: RoleKind.management,
      role: role.name,
      costPerWeek: EconomyBalance.managementRoleWagePerWeek[role] ?? 0,
      hiredAt: hiredAt,
    );
    _staffEntries.add(entry);
    return entry;
  }

  /// Entlässt einen Nicht-Kampf-Personal-Eintrag beliebiger Kategorie (Option C).
  void fireStaffEntry(StaffEntryData entry) {
    _supportStaff.removeWhere((e) => e.id == entry.id);
    _staffEntries.removeWhere((e) => e.id == entry.id);
  }

  /// Stellt einen Teamarzt ein.
  ///
  /// Die Wochenkosten werden aus Qualität und **aktueller Teamgröße** neu
  /// berechnet (§ 4.5). Die erste Abbuchung erfolgt erst zum nächsten
  /// Wochen-Tick (kein anteiliger Einzug).
  void hireMedic(ObjectTeamMedic medic) {
    medic.costPerWeek = EconomyService.weeklyMedicCost(
      medic.quality,
      personalCount,
      PersonalityTraits.forProfile(medic.enneagramProfile.id, medic.id)
          .thriftiness,
    );
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
  /// [random]/[now] sind optional injizierbar (V7/L7) – damit sind
  /// Persönlichkeitswahl und ID deterministisch testbar.
  bool hireApprentice({
    int cost = EconomyBalance.hireApprenticeCost,
    Random? random,
    DateTime? now,
  }) {
    if (!EconomyService.canAfford(budget: budget, cost: cost)) {
      return false; // Negativgrenze würde überschritten
    }
    budget -= cost;
    final rng = random ?? Random();
    final createdAt = now ?? DateTime.now();
    // Küche bestimmt Namensstamm und Token-Grafik (§ 9); die Persönlichkeit
    // wird zufällig aus den zwölf Enneagramm-Profilen gewählt (V9).
    final apprentice = ObjectApprentice(
      cuisine: activeCuisine,
      personalityId: rng.nextInt(EnneagramProfile.all.length),
    );
    // Stabile ID erst nach der Namensgenerierung (V9): Sie ist die Referenz
    // für Persönlichkeits-Varianz und Ressourcen.
    apprentice.id = CRC32.compute(
        apprentice.name + createdAt.toIso8601String());
    final traits =
        PersonalityTraits.forProfile(apprentice.personalityId, apprentice.id);
    apprentice.vitalityCurrent = traits.vitality;
    apprentice.moraleCurrent = traits.morale;
    _personal.add(apprentice);
    return true;
  }

  /// Entlässt einen Charakter unwiderruflich aus dem Team.
  ///
  /// Es gibt keine Rückerstattung des Anheuerungspreises. Fällt dabei der
  /// aktive Chef de cuisine aus, rückt ein formeller Chef nach (V10 § 6).
  void fireCharacter(ObjectApprentice character) {
    final wasActiveHeadChef = character.rank == kRankHeadChef &&
        character.headChefRole == kHeadChefRoleActive;
    _personal.remove(character);
    if (wasActiveHeadChef) nachrueckenHeadChef();
  }

  /// Verschiebt [staff] gegen die Transferkosten in das Restaurant
  /// [targetRestaurantId] (Karrierepfade, V10 – Personal-Transfer).
  ///
  /// Das **Ziel-Restaurant zahlt** (`EconomyService.transferCost`). Die
  /// Verschiebung wird **erst beim nächsten Speichern** wirksam
  /// ([toProfileData]/[saveToStorage]): die Quelle verliert den Charakter
  /// sofort (In-Memory-Zustand für die UI), das nicht-aktive Ziel wird als
  /// aufgeschobene Änderung vorgemerkt.
  ///
  /// Abgelehnt (Rückgabe `false`, Zustand unverändert), wenn der Charakter
  /// nicht (mehr) im Team ist, das Ziel unbekannt oder aufgelöst ist, das Ziel
  /// das aktive Restaurant ist oder das Ziel-Budget die Kosten nicht tragen
  /// kann ([EconomyService.canAfford]). Die Charakter-Identität bleibt erhalten.
  bool transferStaff({
    required ObjectApprentice staff,
    required int targetRestaurantId,
  }) {
    if (!_personal.contains(staff)) return false;
    if (targetRestaurantId == activeRestaurantId) return false;

    final target = _findRestaurant(targetRestaurantId);
    if (target == null || target.isDissolved) return false;

    final cost = EconomyService.transferCost(level: staff.levelValue);

    final existing = _pendingTargetEdits[targetRestaurantId];
    final pendingDelta = existing?.budgetDelta ?? 0;
    if (!EconomyService.canAfford(
        budget: target.budget + pendingDelta, cost: cost)) {
      return false;
    }

    // Quelle (aktives Restaurant): sofort aus dem Team entfernen.
    final wasActiveHeadChef = staff.rank == kRankHeadChef &&
        staff.headChefRole == kHeadChefRoleActive;
    _personal.remove(staff);
    // V10 § 6: Im Ziel ist der transferierte Chef zunächst **formell**; im
    // Quell-Restaurant rückt ein formeller Chef nach.
    if (wasActiveHeadChef) {
      staff.headChefRole = kHeadChefRoleFormal;
      staff.assignedRestaurantId = null;
    }

    // Ziel (nicht-aktiv): für den nächsten Speichervorgang vormerken.
    final edit = existing ?? _TargetRestaurantEdit();
    edit.appendStaff.add(_apprenticeToStaffData(staff));
    edit.budgetDelta -= cost;
    _pendingTargetEdits[targetRestaurantId] = edit;

    if (wasActiveHeadChef) nachrueckenHeadChef();
    return true;
  }

  /// Bildet einen Lehrling zu einem [ObjectLineCook] fort, sofern er
  /// Level 5 oder höher erreicht hat.
  ///
  /// Dünner Wrapper um [promoteToRank]; die Kosten bleiben als Parameter
  /// erhalten (Alt-Aufrufer/Tests), Standard ist
  /// `EconomyBalance.upgradeToLineCookCost`.
  ObjectApprentice? upgradeToLineCook(ObjectApprentice apprentice,
          {int cost = EconomyBalance.upgradeToLineCookCost}) =>
      promoteToRank(apprentice, kRankLineCook, cost: cost);

  /// Befördert [character] in den Zielrang [targetRank] (Karrierepfade, V10).
  ///
  /// Voraussetzungen: [character] steht genau eine Stufe unter dem Zielrang
  /// (`EconomyService.previousRankOf`), erreicht das Level-Gate
  /// (`EconomyService.canPromote`) und das Budget deckt die Einmalkosten bis
  /// zur Negativgrenze (`EconomyService.canAfford`).
  ///
  /// Die Identität bleibt vollständig erhalten (V9/V10): stabile `id`,
  /// Persönlichkeit, Ressourcen, Match-Historie, Verletzungszustand,
  /// Rangfortschritt und gewählte Station wandern in das neue Klassenobjekt;
  /// nur der Rang-Präfix des Namens wechselt (Beförderung, keine Neuwürfelung).
  ///
  /// Gibt den beförderten [ObjectApprentice] zurück – oder `null`, wenn eine
  /// Bedingung nicht erfüllt ist (der Zustand bleibt dann unverändert).
  ObjectApprentice? promoteToRank(
    ObjectApprentice character,
    String targetRank, {
    int? cost,
  }) {
    final previousRank = EconomyService.previousRankOf(targetRank);
    if (previousRank == null || character.rank != previousRank) {
      return null; // falscher Ausgangsrang oder unbekannter Zielrang
    }
    if (!EconomyService.canPromote(
        rank: targetRank, level: character.levelValue)) {
      return null; // Level-Gate nicht erreicht
    }
    final promotionCost = cost ?? EconomyService.promotionCost(targetRank);
    if (!EconomyService.canAfford(budget: budget, cost: promotionCost)) {
      return null; // Budget reicht nicht
    }

    final promoted = _createForRank(
      targetRank,
      name: _rankPrefixedName(character.name, targetRank),
      imagePath: character.imagePath,
    );
    if (promoted == null) return null; // Rang (noch) ohne Klasse

    budget -= promotionCost;
    _transferIdentity(promoted, character);

    // V10 § 6: Beförderung überschreitet die Unikat-Invariante nicht – ein neuer
    // Chef de cuisine startet immer als **formeller** Titelträger und wird nur
    // ausdrücklich zugeteilt (`assignHeadChef`). Bewusst **nach** dem
    // Identitätstransfer, damit die Rolle nicht überschrieben wird.
    if (targetRank == kRankHeadChef) {
      promoted.headChefRole = kHeadChefRoleFormal;
      promoted.assignedRestaurantId = null;
    }

    _personal.remove(character);
    _personal.add(promoted);
    return promoted;
  }

  /// Erzeugt das Klassenobjekt zum Zielrang.
  ///
  /// Umgesetzt sind alle Ränge der Aufstiegsleiter: `line_cook`
  /// ([ObjectLineCook]), `chef_de_partie` ([ObjectChefDePartie]), `sous_chef`
  /// ([ObjectSousChef]) und `head_chef` ([ObjectHeadChef]). Die Küche bestimmt
  /// Namensstamm und Token-Grafik (§ 9).
  ObjectApprentice? _createForRank(
    String targetRank, {
    required String name,
    required String? imagePath,
  }) {
    switch (targetRank) {
      case kRankLineCook:
        return ObjectLineCook(
          cuisine: activeCuisine,
          name: name,
          imagePath: imagePath,
        );
      case kRankChefDePartie:
        return ObjectChefDePartie(
          cuisine: activeCuisine,
          name: name,
          imagePath: imagePath,
        );
      case kRankSousChef:
        return ObjectSousChef(
          cuisine: activeCuisine,
          name: name,
          imagePath: imagePath,
        );
      case kRankHeadChef:
        return ObjectHeadChef(
          cuisine: activeCuisine,
          name: name,
          imagePath: imagePath,
        );
      default:
        return null;
    }
  }

  /// Überträgt Identität, Fortschritt, Zustand und Station von [source] auf
  /// [target] (V9/V10) – die einzige Stelle des Identitätserhalts bei Aufstieg.
  static void _transferIdentity(
      ObjectApprentice target, ObjectApprentice source) {
    target.levelValue = source.levelValue;
    target.currentXPValue = source.currentXPValue;
    target.woundValue = source.woundValue;
    target.status = source.status;
    target.injuryStartedAt = source.injuryStartedAt;
    target.injuryStartStatus = source.injuryStartStatus;
    target.emergencyShotAt = source.emergencyShotAt;
    target.suppressedStatus = source.suppressedStatus;
    target.matchHistory = List.of(source.matchHistory);
    target.id = source.id;
    target.personalityId = source.personalityId;
    target.vitalityCurrent = source.vitalityCurrent;
    target.moraleCurrent = source.moraleCurrent;
    target.lastResourceRefillAt = source.lastResourceRefillAt;
    target.personalityOverrideId = source.personalityOverrideId;
    target.personalityOverrideUntil = source.personalityOverrideUntil;
    target.personalityOverrideCause = source.personalityOverrideCause;
    target.vitalityZeroSinceAt = source.vitalityZeroSinceAt;
    target.moraleZeroSinceAt = source.moraleZeroSinceAt;
    target.station = source.station;
    target.headChefRole = source.headChefRole;
    target.assignedRestaurantId = source.assignedRestaurantId;
  }

  /// Wählt bzw. wechselt die Küchenstation eines Charakters (V10, Phase 4).
  ///
  /// Voraussetzungen: Rang `chef_de_partie` oder höher, [station] ist bekannt
  /// und Varianten setzen ihre Basis-Station voraus. Die erste Wahl ist
  /// kostenfrei; ein Wechsel kostet `EconomyBalance.stationSwitchCost` (bis zur
  /// Negativgrenze, `canAfford`). Gibt `true` zurück, wenn die Station gesetzt
  /// wurde.
  bool assignStation(ObjectApprentice character, String station) {
    if (!EconomyService.isStationRank(character.rank)) return false;
    if (!EconomyService.isValidStation(station)) return false;
    if (character.station == station) return true; // unverändert, kostenfrei

    // Varianten setzen ihre Basis-Station voraus: Die aktuell gewählte Station
    // muss die Basis selbst oder eine Variante derselben Basis sein.
    final targetBase = EconomyService.baseStationOf(station);
    if (targetBase != null &&
        _baseStationKeyOf(character.station) != targetBase) {
      return false;
    }

    final isSwitch = character.station != null;
    final cost = isSwitch ? EconomyBalance.stationSwitchCost : 0;
    if (!EconomyService.canAfford(budget: budget, cost: cost)) return false;
    budget -= cost;
    character.station = station;
    return true;
  }

  /// Basis-Schlüssel einer gewählten Station: eine Variante liefert ihre
  /// Basis, eine Basis-Station sich selbst, `null` bleibt `null`.
  static String? _baseStationKeyOf(String? station) => station == null
      ? null
      : (EconomyService.baseStationOf(station) ?? station);

  // ── Chef de cuisine: Doppelrolle & Unikat-Invariante (V10 § 6) ─────────

  /// Der aktuell **aktive** (zugeteilte) Chef de cuisine dieses Restaurants –
  /// oder `null`. Pro Restaurant ist höchstens einer möglich.
  ObjectApprentice? activeHeadChef() {
    for (final character in _personal) {
      if (character.rank == kRankHeadChef &&
          character.headChefRole == kHeadChefRoleActive) {
        return character;
      }
    }
    return null;
  }

  /// Kandidaten für das Nachrücken: alle **formellen** Chef de cuisine,
  /// sortiert nach höchstem Level, bei Gleichstand nach ältester (kleinster) ID.
  List<ObjectApprentice> formalHeadChefCandidates() {
    final candidates = _personal
        .where((c) =>
            c.rank == kRankHeadChef && c.headChefRole != kHeadChefRoleActive)
        .toList();
    candidates.sort((a, b) {
      final byLevel = b.levelValue.compareTo(a.levelValue);
      return byLevel != 0 ? byLevel : a.id.compareTo(b.id);
    });
    return candidates;
  }

  /// Teilt [character] als **aktiven** Chef de cuisine diesem Restaurant zu
  /// (Karrierepfade, V10 § 6).
  ///
  /// Abgelehnt (`false`, Zustand unverändert), wenn [character] kein Chef de
  /// cuisine im Team ist oder bereits ein aktiver Chef zugeteilt ist
  /// (Unikat-Invariante). Ein Rückweg aktiv → formell ist bewusst **nicht**
  /// vorgesehen (V10 § 6: Reversibilität einseitig).
  bool assignHeadChef(ObjectApprentice character) {
    if (character.rank != kRankHeadChef) return false;
    if (!_personal.contains(character)) return false;
    if (activeHeadChef() != null) return false;
    character.headChefRole = kHeadChefRoleActive;
    character.assignedRestaurantId = activeRestaurantId;
    return true;
  }

  /// Lässt bei Ausfall des aktiven Chef de cuisine den ranghöchsten formellen
  /// Chef nachrücken (V10 § 6: „Ausfall“ = Tod, Entlassung oder Transfer).
  ///
  /// Die Auswahl ist deterministisch (höchstes Level, dann kleinste ID) und
  /// damit testbar; die UI meldet den Nachrücker. Gibt den Nachrücker zurück –
  /// oder `null`, wenn der Posten besetzt ist bzw. kein Chef verfügbar ist.
  ObjectApprentice? nachrueckenHeadChef() {
    if (activeHeadChef() != null) return null;
    final candidates = formalHeadChefCandidates();
    if (candidates.isEmpty) return null;
    final next = candidates.first;
    next.headChefRole = kHeadChefRoleActive;
    next.assignedRestaurantId = activeRestaurantId;
    return next;
  }

  /// Rang-Präfixe der internen Anzeigenamen (Alt-Muster `Apprentice: …`).
  static const Map<String, String> _rankNamePrefixes = {
    kRankApprentice: 'Apprentice: ',
    kRankLineCook: 'Line Cook: ',
    kRankChefDePartie: 'Chef de partie: ',
    kRankSousChef: 'Sous-chef: ',
    kRankHeadChef: 'Chef de cuisine: ',
  };

  /// Ersetzt einen bekannten Rang-Präfix im Namen durch den Präfix von
  /// [targetRank]. Namen ohne bekannten Präfix bleiben unverändert (defensiv).
  static String _rankPrefixedName(String name, String targetRank) {
    final targetPrefix = _rankNamePrefixes[targetRank];
    if (targetPrefix == null) return name;
    for (final prefix in _rankNamePrefixes.values) {
      if (name.startsWith(prefix)) {
        return '$targetPrefix${name.substring(prefix.length)}';
      }
    }
    return name;
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
  void _performSurvivalRolls({Random? random, DateTime? now}) {
    final rng = random ?? Random();
    final nowTime = now ?? DateTime.now();
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
      // V9 § 6: Der kumulative Erschöpfungs-Malus mindert alle W100-Zielwerte.
      targetValue -= StressService.malusPercentForCharacter(unit, nowTime);

      // Erster Rettungswurf
      int roll = EconomyService.rollD100(rng);
      if (roll <= EconomyService.clampTargetToD100(targetValue)) {
        // Gerettet! Verletzungsstatus setzen (nicht tot).
        // V3: `injuryStartedAt` ist der Anker der Echtzeit-Heilung; alte
        // Spritzen-Marker werden verworfen (neue Verletzung).
        unit.injuryStartedAt = nowTime;
        unit.injuryStartStatus = CharacterStatus.dying;
        unit.emergencyShotAt = null;
        unit.suppressedStatus = null;
        unit.status = CharacterStatus.dying;
        continue;
      }

      // Bei Misserfolg und vorhandenem Teamarzt: Wiederholung gegen Bezahlung.
      // Der Wächter folgt der einheitlichen Negativgrenzen-Regel (V7/L4).
      if (hasMedic &&
          EconomyService.canAfford(
              budget: budget, cost: EconomyBalance.revivalCost)) {
        budget -= EconomyBalance.revivalCost; // Kosten für Wiederbelebung
        roll = EconomyService.rollD100(rng);
        if (roll <= EconomyService.clampTargetToD100(targetValue)) {
          unit.injuryStartedAt = nowTime;
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

    // V10 § 6: Fällt der aktive Chef de cuisine im Gefecht, rückt ein formeller
    // Chef automatisch nach (Auswahl: höchstes Level, dann älteste ID).
    nachrueckenHeadChef();
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
  void syncUnitsAfterBattle(List<ObjectApprentice> survivors,
      {Random? random, DateTime? now}) {
    // V9 (Phase 3/4): Ein Gefechtseinsatz kostet Vitalität und Moral und kann
    // Stress oder Ruhe auslösen (W100-Proben, § 6; injizierbarer Zufall).
    final battleRng = random ?? Random();
    final battleNow = now ?? DateTime.now();
    for (final survivor in survivors) {
      final vitalitySink = StressService.sink(
          survivor.vitalityCurrent, EconomyBalance.resourceSinkPerBattle);
      final moraleSink = StressService.sink(
          survivor.moraleCurrent, EconomyBalance.resourceSinkPerBattle);
      survivor.vitalityCurrent = vitalitySink.value;
      survivor.moraleCurrent = moraleSink.value;
      survivor.vitalityZeroSinceAt = StressService.updateZeroAnchor(
          survivor.vitalityZeroSinceAt,
          atZero: vitalitySink.atZero,
          now: battleNow);
      survivor.moraleZeroSinceAt = StressService.updateZeroAnchor(
          survivor.moraleZeroSinceAt,
          atZero: moraleSink.atZero,
          now: battleNow);
      final override = StressService.probe(
        vitalityCurrent: survivor.vitalityCurrent,
        moraleCurrent: survivor.moraleCurrent,
        currentProfileId: survivor.personalityId,
        random: battleRng,
        malusPercent:
            StressService.malusPercentForCharacter(survivor, battleNow),
      );
      if (override != null) {
        survivor.personalityOverrideId = override.profileId;
        survivor.personalityOverrideUntil = battleNow.add(override.duration);
        survivor.personalityOverrideCause = override.cause;
      }
    }

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
    _performSurvivalRolls(random: random, now: now);

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
      final shotCost = EconomyBalance.emergencyShotCost;
      if (!EconomyService.canAfford(budget: budget, cost: shotCost)) continue;
      budget -= shotCost;
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
    lastMatchResult = null;
    lastSeenAt = DateTime.now();
    weekAnchorAt = DateTime.now();
    activeCuisine = Cuisine.italian;
    rebrandingPenaltyUntil = null;
    activeUpgrades = {};
    _personal.clear();
    _hiredMedics.clear();
    _supportStaff.clear();
    _staffEntries.clear();
    _pendingTargetEdits.clear();
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
    _pendingTargetEdits.clear();
    id = data.id;
    name = data.name;
    profileImagePath = data.profileImagePath;

    final restaurant = _resolveRestaurant(data, restaurantId);
    if (restaurant == null) {
      activeRestaurantId = -1;
      activeDistrict = null;
      restaurantName = '';
      restaurantLogoPath = null;
      budget = startBudget;
      lastMatchResult = null;
      lastSeenAt = null;
      weekAnchorAt = null;
      activeCuisine = Cuisine.italian;
      rebrandingPenaltyUntil = null;
      activeUpgrades = {};
      _personal.clear();
      _hiredMedics.clear();
      _supportStaff.clear();
      _staffEntries.clear();
      return;
    }

    activeRestaurantId = restaurant.id;
    activeDistrict = restaurant.district;
    restaurantName = restaurant.name;
    restaurantLogoPath = restaurant.logoPath;
    budget = restaurant.budget;
    lastMatchResult = restaurant.lastMatchResult;
    lastSeenAt = restaurant.lastSeenAt;
    weekAnchorAt = restaurant.weekAnchorAt;
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

    // Restore Hilfs-/Service-Rollen (V10, Phase 6) – unbekannte Rollen werden
    // tolerant übersprungen (V6).
    _supportStaff.clear();
    for (final sd in restaurant.supportStaff) {
      if (SupportRole.values.any((r) => r.name == sd.role)) {
        _supportStaff.add(sd);
      }
    }

    // Generalisiertes Nicht-Kampf-Personal (Option C): Kategorie-erhaltend
    // übernehmen – unbekannte Rollen werden tolerant übersprungen (V6).
    _staffEntries.clear();
    for (final entry in restaurant.staffEntries) {
      final known = switch (entry.kind) {
        RoleKind.support => SupportRole.values.any((r) => r.name == entry.role),
        RoleKind.management =>
          ManagementRole.values.any((r) => r.name == entry.role),
        RoleKind.medic => false,
      };
      if (known) _staffEntries.add(entry);
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

    // V10: aufgeschobene Änderungen an nicht-aktiven Restaurants anwenden
    // (Personal-Transfer) und danach verwerfen – sie sind nun persistiert.
    if (_pendingTargetEdits.isNotEmpty) {
      _pendingTargetEdits.forEach((targetId, edit) {
        final index = restaurants.indexWhere((r) => r.id == targetId);
        if (index < 0) return;
        restaurants[index] = restaurants[index].copyWith(
          staff: [...restaurants[index].staff, ...edit.appendStaff],
          budget: restaurants[index].budget + edit.budgetDelta,
        );
      });
      _pendingTargetEdits.clear();
    }

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
      supportStaff: List.of(_supportStaff),
      staffEntries: List.of(_staffEntries),
      upgrades: Map.of(activeUpgrades),
      // V3/V8: den (ggf. durch den Catch-up fortgeschriebenen) Zeitanker
      // persistieren, damit verpasste Zeit nicht erneut abgerechnet wird.
      lastSeenAt: lastSeenAt ??
          (existingIndex >= 0 ? restaurants[existingIndex].lastSeenAt : null) ??
          DateTime.now(),
      weekAnchorAt: weekAnchorAt ??
          (existingIndex >= 0 ? restaurants[existingIndex].weekAnchorAt : null),
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

    final result = ProfileData(
      id: id,
      name: name,
      creationDate: _profileData?.creationDate ?? DateTime.now(),
      profileImagePath: profileImagePath,
      restaurants: restaurants,
    );
    // Die gemergte Fassung wird zur neuen Merge-Basis: So bleiben auch
    // Änderungen an nicht-aktiven Restaurants (Personal-Transfer) über mehrere
    // Aufrufe hinweg stabil und werden nicht doppelt oder gar nicht angewendet.
    _profileData = result;
    return result;
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
        supportStaff: List.of(_supportStaff),
        staffEntries: List.of(_staffEntries),
        upgrades: Map.of(activeUpgrades),
        lastSeenAt: lastSeenAt,
        weekAnchorAt: weekAnchorAt,
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
    if (!EconomyService.canAfford(budget: budget, cost: cost)) return false;
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
  WeeklyTickResult runCatchUp(DateTime now, {Random? random}) {
    final snapshot = activeRestaurantSnapshot();
    final result = GameClockService.catchUp(snapshot, now, random: random);
    budget = snapshot.budget;
    lastSeenAt = snapshot.lastSeenAt;
    weekAnchorAt = snapshot.weekAnchorAt;
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
      character.vitalityCurrent =
          sd.vitalityCurrent ?? character.vitalityCurrent;
      character.moraleCurrent = sd.moraleCurrent ?? character.moraleCurrent;
      character.lastResourceRefillAt = sd.lastResourceRefillAt;
      character.personalityOverrideId = sd.personalityOverrideId;
      character.personalityOverrideUntil = sd.personalityOverrideUntil;
      character.personalityOverrideCause = sd.personalityOverrideCause;
      character.vitalityZeroSinceAt = sd.vitalityZeroSinceAt;
      character.moraleZeroSinceAt = sd.moraleZeroSinceAt;
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

  // ── Konvertierungshilfen ───────────────────────────────────────────────

  static StaffData _apprenticeToStaffData(ObjectApprentice a) => StaffData(
        name: a.name,
        imagePath: a.imagePath,
        type: a.rank,
        rank: a.rank,
        station: a.station,
        headChefRole: a.headChefRole,
        assignedRestaurantId: a.assignedRestaurantId,
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
        id: a.id,
        personalityId: a.personalityId,
        vitalityCurrent: a.vitalityCurrent,
        moraleCurrent: a.moraleCurrent,
        lastResourceRefillAt: a.lastResourceRefillAt,
        personalityOverrideId: a.personalityOverrideId,
        personalityOverrideUntil: a.personalityOverrideUntil,
        personalityOverrideCause: a.personalityOverrideCause,
        vitalityZeroSinceAt: a.vitalityZeroSinceAt,
        moraleZeroSinceAt: a.moraleZeroSinceAt,
        matchHistory: a.matchHistory.map((m) => m.toJson()).toList(),
      );

  static ObjectApprentice? _staffDataToApprentice(StaffData sd) {
    // Karriere-Rang ist führend; `type` bleibt als Fallback für Alt-Daten (V10).
    final rank = sd.rank.isNotEmpty ? sd.rank : rankFromType(sd.type);
    if (rank == kRankLineCook) {
      return _buildApprentice<ObjectLineCook>(sd, ObjectLineCook());
    }
    if (rank == kRankChefDePartie) {
      return _buildApprentice<ObjectChefDePartie>(sd, ObjectChefDePartie());
    }
    if (rank == kRankSousChef) {
      return _buildApprentice<ObjectSousChef>(sd, ObjectSousChef());
    }
    if (rank == kRankHeadChef) {
      return _buildApprentice<ObjectHeadChef>(sd, ObjectHeadChef());
    }
    // Alle anderen Ränge (u. a. die späteren höheren Klassen) werden vorerst als
    // Basisklasse geladen; der Rang bleibt in `apprentice.rank` erhalten.
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
    apprentice.rank = sd.rank.isNotEmpty ? sd.rank : rankFromType(sd.type);
    // Gewählte Küchenstation (Phase 4) – additiv/tolerant, `null` bei Alt-Daten.
    apprentice.station = sd.station;
    // Doppelrolle des Chef de cuisine (Phase 5) – additiv/tolerant.
    apprentice.headChefRole = sd.headChefRole;
    apprentice.assignedRestaurantId = sd.assignedRestaurantId;
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
    // Identität & Persönlichkeit (V9): stabile ID und Profil sicherstellen.
    // Alt-Daten ohne Felder werden deterministisch aus dem Namen abgeleitet
    // (kein Neu-Würfeln bei jedem Laden).
    apprentice.id = sd.id >= 0 ? sd.id : CRC32.compute(sd.name);
    apprentice.personalityId = sd.personalityId >= 0
        ? sd.personalityId
        : CRC32.compute(sd.name) % EnneagramProfile.all.length;
    final traits =
        PersonalityTraits.forProfile(apprentice.personalityId, apprentice.id);
    apprentice.vitalityCurrent = sd.vitalityCurrent ?? traits.vitality;
    apprentice.moraleCurrent = sd.moraleCurrent ?? traits.morale;
    apprentice.lastResourceRefillAt = sd.lastResourceRefillAt;
    apprentice.personalityOverrideId = sd.personalityOverrideId;
    apprentice.personalityOverrideUntil = sd.personalityOverrideUntil;
    apprentice.personalityOverrideCause = sd.personalityOverrideCause;
    apprentice.vitalityZeroSinceAt = sd.vitalityZeroSinceAt;
    apprentice.moraleZeroSinceAt = sd.moraleZeroSinceAt;

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
        personalityId: m.enneagramProfile.id,
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
    // Bevorzugt der stabile Index (V9); der Anzeigename bleibt Fallback für
    // Alt-Spielstände (V6-Prinzip).
    final medicProfileId = md.personalityId;
    medic.enneagramProfile = medicProfileId != null &&
            medicProfileId >= 0 &&
            medicProfileId < EnneagramProfile.all.length
        ? EnneagramProfile.all[medicProfileId]
        : EnneagramProfile.byName(md.enneagramProfileName);
    return medic;
  }
}