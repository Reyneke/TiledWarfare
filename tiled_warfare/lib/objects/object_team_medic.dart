import 'dart:math';

import 'package:tiled_warfare/fuzzy_logic/lib/fuzzylogic.dart';
import 'package:tiled_warfare/objects/object_token.dart';
import 'package:tiled_warfare/objects/object_host.dart';
import 'package:tiled_warfare/objects/player_objects/object_apprentice.dart';
import 'package:tiled_warfare/utils/crc32.dart' show CRC32;
import 'package:random_name_generator/random_name_generator.dart';

/// Qualitätsstufen des Teamarztes.
///
/// Bestimmt die Kosten und die Wirksamkeit des Arztes.
enum MedicQuality {
  /// Günstig, geringer Bonus auf Rettungswürfe und Heilung.
  niedrig(1.0, 10, Duration(hours: 6)),

  /// Mittelklasse, solider Bonus.
  mittel(2.0, 20, Duration(hours: 3)),

  /// Hochwertig, maximale Boni.
  hoch(3.0, 30, Duration(hours: 1));

  /// Kostenmultiplikator relativ zur Basis.
  final double costMultiplier;

  /// Bonus auf den Rettungswurf-Zielwert (W100).
  final int survivalBonus;

  /// Dauer bis zur Heilung einer Verletzungsstufe.
  final Duration healTimePerStage;

  const MedicQuality(
    this.costMultiplier,
    this.survivalBonus,
    this.healTimePerStage,
  );
}

/// Fuzzy-Variable für die Hilfsbereitschaft des Teamarztes (0–100).
///
/// Beeinflusst, wie wahrscheinlich der Arzt auf eine Bitte des Spielers
/// reagiert und wie gut seine Behandlung tatsächlich wirkt.
class MedicHelpfulness extends FuzzyVariable<int> {
  var Unhelpful = FuzzySet.LeftShoulder(0, 20, 40);
  var Neutral = FuzzySet.Triangle(20, 50, 80);
  var Helpful = FuzzySet.RightShoulder(60, 80, 100);

  MedicHelpfulness() {
    sets = [Unhelpful, Neutral, Helpful];
    init();
  }
}

/// Fuzzy-Variable für die Erfolgsqualität einer Behandlung (0–100).
class MedicTreatmentQuality extends FuzzyVariable<int> {
  var Poor = FuzzySet.LeftShoulder(0, 20, 40);
  var Average = FuzzySet.Triangle(20, 50, 80);
  var Excellent = FuzzySet.RightShoulder(60, 80, 100);

  MedicTreatmentQuality() {
    sets = [Poor, Average, Excellent];
    init();
  }
}

/// Repräsentiert einen Teamarzt, der zwischen den Gefechten angeheuert werden kann.
///
/// Der Teamarzt nimmt nicht aktiv am Gefecht teil, sondern verbessert die
/// Überlebenschancen und Heilungsrate der Teammitglieder (siehe `team_rules.md`,
/// Abschnitt 4.5).
///
/// Analog zu [ObjectHost] besitzt der Teamarzt eine Persönlichkeit, die sich aus
/// einem zufälligen [EnneagramProfile] und Fuzzy Logic zusammensetzt. Diese
/// Persönlichkeit beeinflusst seine [MedicQuality], die wöchentlichen Kosten,
/// seine tatsächliche Hilfsbereitschaft und die Erfolgswahrscheinlichkeit seiner
/// Behandlungen.
class ObjectTeamMedic {
  /// Eindeutige ID, bestehend aus einem CRC32-Hash des Namens und des
  /// Erstellungsdatums.
  int id;

  /// Zufällig generierter italienischer Name.
  String name;

  /// Qualitätsstufe des Teamarztes.
  ///
  /// Wird durch die Persönlichkeit (Enneagramm + Fuzzy) beeinflusst.
  MedicQuality quality;

  /// Die wöchentlichen Kosten des Teamarztes in Euro.
  ///
  /// Berechnet aus [quality] und der Teamzusammensetzung.
  /// Wird im Konstruktor-Rumpf gesetzt, da [quality] zu diesem Zeitpunkt
  /// bereits initialisiert ist.
  late int costPerWeek;

  /// Das zufällig gewählte Enneagramm-Profil des Teamarztes.
  EnneagramProfile enneagramProfile;

  /// Fuzzy-Variable für die Hilfsbereitschaft.
  final MedicHelpfulness helpfulness = MedicHelpfulness();

  /// Fuzzy-Variable für die Behandlungsqualität.
  final MedicTreatmentQuality treatmentQuality = MedicTreatmentQuality();

  /// Fuzzy-Regelbasis für die Persönlichkeit des Teamarztes.
  final FuzzyRuleBase ruleBase = FuzzyRuleBase();

  /// Zufallsgenerator für Persönlichkeitsentscheidungen.
  final Random _random = Random();

  /// Erzeugt einen neuen Teamarzt.
  ///
  /// Der [name] wird automatisch als zufälliger italienischer Name generiert.
  /// [id] wird aus einem CRC32-Hash von [name] und dem aktuellen Datum
  /// berechnet.
  /// [quality] wird zufällig gewählt – [costPerWeek] wird daraus konsistent
  /// berechnet (beide nutzen denselben Qualitätswert).
  /// [personalCostMultiplier] gibt an, wie stark die Teamgröße die Kosten
  /// beeinflusst (Standard: 1.0, höher für größere Teams).
  ObjectTeamMedic({double personalCostMultiplier = 1.0})
      : name = RandomNames(Zone.italy).fullName(),
        id = 0, // temporary; will be computed in constructor body
        enneagramProfile =
            EnneagramProfile.all[Random().nextInt(EnneagramProfile.all.length)],
        quality = MedicQuality.values[Random().nextInt(MedicQuality.values.length)] {
    // Compute ID from the actual name and current timestamp (not a duplicate random name).
    id = CRC32.compute('$name${DateTime.now().toIso8601String()}');
    costPerWeek = _computeWeeklyCost(quality, personalCostMultiplier);
    _initializeFuzzyRules();
  }

  /// Berechnet die wöchentlichen Kosten basierend auf Qualität und Teamgröße.
  ///
  /// Gemäß team_rules.md Abschnitt 4.5:
  /// - Höhere Qualität kostet mehr (über [MedicQuality.costMultiplier]).
  /// - Größere/mächtigere Teams erhöhen die Kosten.
  static int _computeWeeklyCost(MedicQuality quality, double teamMultiplier) {
    // Basis: 500 €/Woche für niedrigste Qualität und kleinstes Team.
    const baseCost = 500;
    return (baseCost * quality.costMultiplier * teamMultiplier).round();
  }

  /// Initialisiert die Fuzzy-Regeln basierend auf dem Enneagramm-Profil.
  ///
  /// Die Persönlichkeit beeinflusst die [helpfulness] und [treatmentQuality]
  /// des Teamarztes. Ein hilfsbereiterer Arzt ist eher bereit, zu helfen,
  /// aber möglicherweise weniger gründlich, während ein weniger hilfsbereiter
  /// Arzt seltener hilft, dann aber mit höherer Qualität.
  void _initializeFuzzyRules() {
    switch (enneagramProfile.name) {
      case 'Der Helfer':
      case 'Der Friedfertige':
        // Sehr hilfsbereit, durchschnittliche Behandlungsqualität
        ruleBase.addRules([
          (helpfulness.Unhelpful) >> (helpfulness.Helpful),
          (treatmentQuality.Poor) >> (treatmentQuality.Average),
        ]);
        break;
      case 'Der Denker':
      case 'Der Stratege':
        // Weniger hilfsbereit, aber hohe Behandlungsqualität, wenn sie helfen
        ruleBase.addRules([
          (helpfulness.Helpful) >> (helpfulness.Unhelpful),
          (treatmentQuality.Poor) >> (treatmentQuality.Excellent),
        ]);
        break;
      case 'Der Chaot':
      case 'Der Enthusiast':
        // Unberechenbar – hohe Streuung in beiden Variablen
        ruleBase.addRules([
          (helpfulness.Unhelpful) >> (helpfulness.Helpful),
          (helpfulness.Helpful) >> (helpfulness.Neutral),
          (treatmentQuality.Poor) >> (treatmentQuality.Excellent),
          (treatmentQuality.Excellent) >> (treatmentQuality.Poor),
        ]);
        break;
      case 'Der Reformierte':
        // Zuverlässig, gute Qualität, aber nicht übermäßig hilfsbereit
        ruleBase.addRules([
          (helpfulness.Unhelpful) >> (helpfulness.Neutral),
          (treatmentQuality.Poor) >> (treatmentQuality.Excellent),
        ]);
        break;
      default:
        // Ausgeglichenes Verhalten
        ruleBase.addRules([
          (helpfulness.Unhelpful) >> (helpfulness.Neutral),
          (helpfulness.Helpful) >> (helpfulness.Neutral),
          (treatmentQuality.Poor) >> (treatmentQuality.Average),
          (treatmentQuality.Excellent) >> (treatmentQuality.Average),
        ]);
        break;
    }
  }

  /// Gibt den Anzeigenamen des Teamarztes zurück.
  String get displayName => 'Dr. $name (${enneagramProfile.name})';

  /// Behandelt einen verletzten Charakter und heilt ihn um eine Stufe.
  ///
  /// Gibt `true` zurück, wenn die Behandlung erfolgreich war, andernfalls
  /// `false` (z. B. weil der Arzt nicht hilfsbereit genug ist oder die
  /// Behandlung fehlschlägt).
  ///
  /// Gemäß team_rules.md Abschnitt 4.3 heilt der Teamarzt eine
  /// Verletzungsstufe pro Echtzeitstunde. Diese Methode heilt den
  /// [CharacterStatus] des Charakters um eine Stufe in der
  /// Heilungsreihenfolge: `dying → injured → hurt → reeling → ready`.
  ///
  /// Die Erfolgswahrscheinlichkeit hängt von der aktuellen [helpfulness] und
  /// [treatmentQuality] ab, die wiederum durch das Enneagramm und die
  /// Fuzzy-Regeln bestimmt werden.
  bool treatCharacter(ObjectApprentice character) {
    // Nur verletzte Charaktere behandeln
    if (character.status == CharacterStatus.ready ||
        character.status == CharacterStatus.dead ||
        character.status == CharacterStatus.overkilled) {
      return false;
    }

    // Hilfsbereitschaft evaluieren: W100-Wurf gegen den aktuellen
    // helpfulness-Wert (Mittelwert der Fuzzy-Mengen).
    final helpfulnessScore = _evaluateHelpfulness();
    if (_random.nextInt(100) + 1 > helpfulnessScore) {
      return false; // Arzt ist nicht hilfsbereit genug.
    }

    // Behandlungsqualität evaluieren.
    final qualityScore = _evaluateTreatmentQuality();
    if (_random.nextInt(100) + 1 > qualityScore) {
      return false; // Behandlung schlägt fehl.
    }

    // Behandlung erfolgreich – Charakter um eine Stufe heilen.
    // Heilungsreihenfolge: dying → injured → hurt → reeling → ready
    switch (character.status) {
      case CharacterStatus.dying:
        character.status = CharacterStatus.injured;
        break;
      case CharacterStatus.injured:
        character.status = CharacterStatus.hurt;
        break;
      case CharacterStatus.hurt:
        character.status = CharacterStatus.reeling;
        break;
      case CharacterStatus.reeling:
        character.status = CharacterStatus.ready;
        break;
      default:
        return false; // Keine Heilung nötig
    }
    return true;
  }

  /// Führt eine Notfall-Spritze durch, die einen schwer verletzten oder
  /// sterbenden Charakter sofort wieder voll einsatzfähig macht (temporärer Effekt).
  ///
  /// Gibt `true` zurück, wenn die Spritze verabreicht wurde.
  ///
  /// Gemäß team_rules.md Abschnitt 4.5:
  /// - Die Spritze schiebt den Schaden nur temporär auf.
  /// - Nach einem Echtzeit-Tag kehren die unterdrückten Verletzungen zurück.
  /// - Die Spritze ist teuer (einmalige Zusatzkosten).
  bool emergencyShot(ObjectToken character) {
    // Nur bei toten (woundValue <= 0) oder sterbenden Charakteren sinnvoll
    final bool isDying = character is ObjectApprentice &&
        character.status == CharacterStatus.dying;
    if (character.woundValue > 0 && !isDying) {
      return false;
    }

    // Hilfsbereitschaft prüfen.
    final helpfulnessScore = _evaluateHelpfulness();
    if (_random.nextInt(100) + 1 > helpfulnessScore) {
      return false;
    }

    // Charakter provisorisch auf 1 Wundstufe setzen (lebend, aber verletzt).
    character.woundValue = 1;

    // Status zurücksetzen, falls es ein ObjectApprentice ist
    if (character is ObjectApprentice) {
      character.status = CharacterStatus.ready;
    }

    // Hinweis: Der zurückkehrende Schaden nach einem Tag muss durch
    // einen Timer/ein Event-System außerhalb dieser Klasse behandelt werden.
    return true;
  }

  /// Gibt den Bonus auf den Rettungswurf-Zielwert zurück, den dieser
  /// Teamarzt bietet.
  ///
  /// Gemäß team_rules.md Abschnitt 4.2:
  /// - Basis-Bonus: +20 (in [MedicQuality] hinterlegt).
  /// - Modifiziert durch die aktuelle [treatmentQuality].
  int get effectiveSurvivalBonus {
    final baseBonus = quality.survivalBonus;
    final qualityModifier = _evaluateTreatmentQuality() ~/ 10;
    return baseBonus + qualityModifier;
  }

  /// Gibt die Dauer zurück, die dieser Teamarzt für die Heilung einer
  /// Verletzungsstufe benötigt.
  ///
  /// Gemäß team_rules.md Abschnitt 4.3:
  /// - Basis: 1 Stunde pro Stufe (statt 1 Tag ohne Arzt).
  /// - Modifiziert durch die aktuelle Behandlungsqualität.
  Duration get effectiveHealTime {
    final baseTime = quality.healTimePerStage;
    final qualityModifier = _evaluateTreatmentQuality();
    // Bessere Qualität = schnellere Heilung (Faktor 0.5 bis 1.5).
    final factor = 1.5 - (qualityModifier / 100.0);
    return Duration(
      milliseconds: (baseTime.inMilliseconds * factor).round(),
    );
  }

  /// Gibt einen deterministischen Score für das Enneagramm-Profil (0–100).
  ///
  /// Verwendet den Index des Profils in der `all`-Liste, um einen
  /// reproduzierbaren und zwischen Runs/Plattformen konsistenten Wert
  /// zu liefern. Ersetzt die frühere `hashCode`-basierte Berechnung,
  /// die nicht portabel war.
  static int _enneagramScore(EnneagramProfile profile) {
    final index = EnneagramProfile.all.indexOf(profile);
    // Gleichmäßige Verteilung über 0–100 (91 = 12 Profile * 7.58)
    return ((index + 1) * 8) % 100;
  }

  /// Bewertet die aktuelle Hilfsbereitschaft auf einer Skala von 0–100.
  ///
  /// Basis sind 50 Punkte, modifiziert durch das Enneagramm-Profil
  /// (0–42 Punkte) und die Qualitätsstufe (0–10 Punkte).
  /// Ergebnis ist deterministisch und reproduzierbar.
  int _evaluateHelpfulness() {
    return 50 + _enneagramScore(enneagramProfile) + quality.survivalBonus;
  }

  /// Bewertet die aktuelle Behandlungsqualität auf einer Skala von 0–100.
  ///
  /// Basis ist der [MedicQuality.survivalBonus] (10–30), modifiziert
  /// durch das Enneagramm-Profil (0–42 Punkte).
  /// Ergebnis ist deterministisch und reproduzierbar.
  int _evaluateTreatmentQuality() {
    return quality.survivalBonus + (_enneagramScore(enneagramProfile) ~/ 2);
  }

  @override
  String toString() =>
      'ObjectTeamMedic(id: $id, name: $name, quality: ${quality.name}, '
      'costPerWeek: $costPerWeek€, personality: ${enneagramProfile.name})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ObjectTeamMedic &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}