import 'package:random_name_generator/random_name_generator.dart';
import 'package:tiled_warfare/models/cuisine.dart';
import 'package:tiled_warfare/models/match_record.dart';
import 'package:tiled_warfare/models/personality.dart';
import 'package:tiled_warfare/objects/object_token.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/economy_service.dart';

/// Status eines Charakters ausserhalb des Gefechts.
///
/// Siehe `doc/rules/team_rules.md` Abschnitt 4.1 für detaillierte
/// Beschreibung der einzelnen Status und ihrer Auswirkungen.
enum CharacterStatus {
  ready(0),
  reeling(1),
  hurt(2),
  afraid(3),
  injured(4),
  dying(5),
  dead(6),
  overkilled(7);

  /// Schweregrad des Status (je höher, desto schwerer verletzt).
  final int severity;
  const CharacterStatus(this.severity);
}

/// Repräsentiert einen angestellten Charakter (Lehrling) im Restaurant-Team.
///
/// Ein Lehrling ist die Einstiegsklasse (siehe `doc/rules/team_rules.md`,
/// Abschnitt 2.3). Er kann durch das Sammeln von Erfahrungspunkten (XP)
/// im Kampf aufsteigen und ab Level 5 zu einem [ObjectLineCook] fortgebildet
/// werden.
///
/// Level-System (gemäß team_rules.md Abschnitt 3.1):
/// - Levelaufstieg erfolgt, sobald currentXPValue ≥ levelValue × 1000
/// - Bei Überschreiten der Schwelle um mehr als das 1.000-Fache werden
///   mehrere Level auf einmal erreicht (überschüssige XP bleiben erhalten).
/// Attribute & Persönlichkeit (V9): Jeder Charakter trägt eine stabile [id],
/// ein Enneagramm-Profil ([personalityId]) sowie die daraus abgeleiteten
/// Ressourcen [vitalityCurrent]/[moraleCurrent] (siehe `9_Personal.md`).
class ObjectApprentice extends ObjectToken {
  /// Aktuelles Level (beginnt bei 1).
  int levelValue = 1;

  /// Aktuelle Erfahrungspunkte (noch nicht für Levelaufstieg verbraucht).
  int currentXPValue = 0;

  /// Aktueller Verletzungs-Status (ready = gesund).
  CharacterStatus status = CharacterStatus.ready;

  /// Beginn der aktuellen Verletzung (V3) – Anker der Echtzeit-Heilung.
  DateTime? injuryStartedAt;

  /// Status zu Beginn der aktuellen Verletzung (V3) – Basis der idempotenten
  /// Neuberechnung des Heilungsfortschritts.
  CharacterStatus? injuryStartStatus;

  /// Zeitpunkt der automatisch verabreichten Notfall-Spritze (V3).
  /// Solange gesetzt und jünger als `EconomyBalance.emergencyShotDuration`,
  /// ist [suppressedStatus] unterdrückt.
  DateTime? emergencyShotAt;

  /// Der von der Notfall-Spritze unterdrückte Status (V3).
  CharacterStatus? suppressedStatus;

  /// Stabile Charakter-ID (V9) – Referenz für Attribute, Persönlichkeit und
  /// Match-Historie (CRC32 aus Name + Erzeugungszeitpunkt; `0` = offen).
  int id = 0;

  /// Index des Enneagramm-Profils in `EnneagramProfile.all` (V9).
  /// `-1` = noch nicht zugewiesen (Legacy/Fallback).
  int personalityId = -1;

  /// Aktueller Vitalitätsstand (V9), Domäne 0–100.
  int vitalityCurrent = 0;

  /// Aktueller Moralstand (V9), Domäne 0–100.
  int moraleCurrent = 0;

  /// Anker für idempotentes Sinken/Auffüllen der Ressourcen (V9).
  DateTime? lastResourceRefillAt;

  /// Temporär wirksames Enneagramm-Profil (Stress/Ruhe, V9 § 6); `-1` = keins.
  int personalityOverrideId = -1;

  /// Ablaufzeitpunkt des Overrides (V9 § 6).
  DateTime? personalityOverrideUntil;

  /// Auslöser des Overrides: `stress` oder `ruhe` (V9 § 6).
  String? personalityOverrideCause;

  /// Seit wann [vitalityCurrent] auf 0 steht (Erschöpfungs-Malus, V9 § 6).
  DateTime? vitalityZeroSinceAt;

  /// Seit wann [moraleCurrent] auf 0 steht (Erschöpfungs-Malus, V9 § 6).
  DateTime? moraleZeroSinceAt;

  /// Effektiv wirksames Enneagramm-Profil: Ein Stress-/Ruhe-Override hat
  /// Vorrang vor dem Grundprofil (V9 § 6).
  EnneagramProfile get effectivePersonality => EnneagramProfile.all[
      EnneagramProfile.normalizeId(
          personalityOverrideId >= 0 ? personalityOverrideId : personalityId)];

  /// Persönlichkeits-Traits dieses Charakters (V9 § 4; berücksichtigt einen
  /// laufenden Stress-/Ruhe-Override).
  PersonalityTraits get traits =>
      PersonalityTraits.forProfile(effectivePersonality.id, id);

  /// Angriffs-Zielwert inkl. Persönlichkeits-Modifikator (V9 Phase 5).
  int get personalityAttackValue =>
      _withTraitPercent(attackValue, traits.aggressiveness);

  /// Verteidigungs-Zielwert inkl. Persönlichkeits-Modifikator (V9 Phase 5).
  int get personalityDefenseValue =>
      _withTraitPercent(defenseValue, traits.aggressiveness);

  /// Schadenswert inkl. Persönlichkeits-Modifikator (V9 Phase 5).
  int get personalityDamageValue =>
      _withTraitPercent(damageValue, traits.riskTolerance);

  /// Bewegungswert inkl. Persönlichkeits-Modifikator (V9 Phase 5).
  int get personalityMovementValue =>
      _withTraitPercent(baseMovementValue, traits.tacticalComplexity);

  /// Wendet den Trait-Anteil als ±-Prozent auf einen Basiswert an.
  static int _withTraitPercent(int base, int trait) {
    final percent =
        ((trait - 50) / 50 * EconomyBalance.combatTraitMaxPercent).round();
    return (base * (100 + percent) / 100).round();
  }

  /// Match-Historie dieses Charakters.
  List<MatchRecord> matchHistory = [];

  /// Erzeugt einen Lehrling.
  ///
  /// [nameZone] wird für die Namenserzeugung genutzt; alternativ kann über
  /// [cuisine] die Küche des Restaurants übergeben werden (§ 9). Ist [nameZone]
  /// nicht gesetzt, wird die Zone der [cuisine] verwendet (Fallback:
  /// [Zone.italy] für Alt-Spielstände).
  ///
  /// [imagePath] fällt auf die Küchen-Token-Grafik ([Cuisine.tokenImagePath])
  /// bzw. auf die generische `token_cook_basic.png` zurück, wenn keine Küche
  /// angegeben ist.
  ObjectApprentice({
    String? name,
    String? imagePath,
    Zone? nameZone,
    Cuisine? cuisine,
    int? attackValue,
    int? defenseValue,
    int? movementValue,
    int? damageValue,
    int? rangeValue,
    int? moneyValue,
    int? xpValue,
    int? id,
    int? personalityId,
    int? vitalityCurrent,
    int? moraleCurrent,
    this.lastResourceRefillAt,
    this.personalityOverrideId = -1,
    this.personalityOverrideUntil,
    this.personalityOverrideCause,
    this.vitalityZeroSinceAt,
    this.moraleZeroSinceAt,
  }) : super(
    name: name ??
        "Apprentice: ${RandomNames(nameZone ?? cuisine?.zone ?? Zone.italy).name()}",
    imagePath: imagePath ??
        cuisine?.tokenImagePath ??
        "assets/images/token/token_cook_basic.png",
    attackValue: attackValue ?? EconomyBalance.apprenticeStats.attack,
    defenseValue: defenseValue ?? EconomyBalance.apprenticeStats.defense,
    movementValue: movementValue ?? EconomyBalance.apprenticeStats.movement,
    damageValue: damageValue ?? EconomyBalance.apprenticeStats.damage,
    rangeValue: rangeValue ?? EconomyBalance.apprenticeStats.range,
    moneyValue: moneyValue ?? EconomyBalance.apprenticeStats.money,
    xpValue: xpValue ?? EconomyBalance.apprenticeStats.xp,
  ) {
    this.id = id ?? 0;
    this.personalityId = personalityId ?? -1;
    final traits = PersonalityTraits.forProfile(this.personalityId, this.id);
    this.vitalityCurrent = (vitalityCurrent ?? traits.vitality)
        .clamp(EconomyBalance.resourceMin, EconomyBalance.resourceMax);
    this.moraleCurrent = (moraleCurrent ?? traits.morale)
        .clamp(EconomyBalance.resourceMin, EconomyBalance.resourceMax);
  }

  /// Fügt [xp] Erfahrungspunkte hinzu und führt ggf. Levelaufstiege durch.
  ///
  /// Gemäß team_rules.md Abschnitt 3.1:
  /// Ein Levelaufstieg erfolgt, sobald `currentXPValue ≥ levelValue × 1000`.
  /// Werden mehrere Schwellen auf einmal überschritten (z. B. 2.500 XP
  /// bei Level 1), steigt der Charakter entsprechend oft auf.
  ///
  /// Gibt `true` zurück, wenn ein oder mehrere Levelaufstiege stattfanden.
  bool earnXP(int xp) {
    currentXPValue += xp;
    bool leveledUp = false;
    // Nach jedem Levelaufstieg wird die neue Schwelle berechnet, damit
    // überschüssige XP korrekt auf die Folgelevel angerechnet werden.
    while (currentXPValue >= EconomyService.levelUpThreshold(levelValue)) {
      currentXPValue -= EconomyService.levelUpThreshold(levelValue);
      levelValue++;
      leveledUp = true;
    }
    return leveledUp;
  }
}