import 'dart:math';

import 'package:tiled_warfare/models/medic_quality.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/economy_service.dart';
import 'package:tiled_warfare/services/stress_service.dart';
import 'package:tiled_warfare/models/personality.dart';
import 'package:tiled_warfare/objects/player_objects/object_apprentice.dart';
import 'package:tiled_warfare/utils/crc32.dart' show CRC32;
import 'package:random_name_generator/random_name_generator.dart';

/// Repräsentiert einen Teamarzt, der zwischen den Gefechten angeheuert werden kann.
///
/// Der Teamarzt nimmt nicht aktiv am Gefecht teil, sondern verbessert die
/// Überlebenschancen und Heilungsrate der Teammitglieder (siehe `team_rules.md`,
/// Abschnitt 4.5).
///
/// Der Teamarzt besitzt ein zufälliges [EnneagramProfile]. Es bestimmt – neben
/// der [MedicQuality] – deterministisch seine Hilfsbereitschaft und die
/// Erfolgswahrscheinlichkeit seiner Behandlungen. Eine frühere Fuzzy-Auswertung
/// wurde entfernt (V5); die Persönlichkeits-Idee wird beim späteren Ausbau des
/// Personalsektors in anderer Form wieder aufgegriffen.
class ObjectTeamMedic {
  /// Eindeutige ID, bestehend aus einem CRC32-Hash des Namens und des
  /// Erstellungsdatums.
  int id;

  /// Zufällig generierter italienischer Name.
  String name;

  /// Qualitätsstufe des Teamarztes (zufällig gewählt).
  MedicQuality quality;

  /// Die wöchentlichen Kosten des Teamarztes in Euro.
  ///
  /// Berechnet aus [quality] und der Teamzusammensetzung.
  /// Wird im Konstruktor-Rumpf gesetzt, da [quality] zu diesem Zeitpunkt
  /// bereits initialisiert ist.
  late int costPerWeek;

  /// Das zufällig gewählte Enneagramm-Profil des Teamarztes.
  EnneagramProfile enneagramProfile;

  /// Zufallsgenerator für die Erfolgswürfe der Behandlung.
  ///
  /// Injizierbar (V7/L7), damit Behandlungen deterministisch testbar sind.
  late final Random _random;

  /// Zeitquelle (injizierbar, V7/L7).
  late final DateTime Function() _now;

  /// Erzeugt einen neuen Teamarzt.
  ///
  /// Der [name] wird automatisch als zufälliger italienischer Name generiert.
  /// [id] wird aus einem CRC32-Hash von [name] und dem aktuellen Datum
  /// berechnet.
  /// [quality] wird zufällig gewählt – [costPerWeek] wird daraus konsistent
  /// berechnet (beide nutzen denselben Qualitätswert).
  /// [teamSize] ist die aktuelle Teamgröße des Restaurants; sie geht in die
  /// Wochenkosten ein (größeres Team = höhere Kosten, § 4.5).
  /// [random]/[now] sind optional injizierbar (Tests); Standard ist die
  /// Systemzeit bzw. ein frischer [Random].
  ObjectTeamMedic({
    int teamSize = 0,
    Zone? nameZone,
    Random? random,
    DateTime Function()? now,
  })  : _random = random ?? Random(),
        _now = now ?? DateTime.now,
        name = RandomNames(nameZone ?? Zone.italy).fullName(),
        id = 0, // temporary; will be computed in constructor body
        enneagramProfile = EnneagramProfile.all[
            (random ?? Random()).nextInt(EnneagramProfile.all.length)],
        quality = MedicQuality.values[
            (random ?? Random()).nextInt(MedicQuality.values.length)] {
    // Compute ID from the actual name and current timestamp (not a duplicate random name).
    id = CRC32.compute('$name${_now().toIso8601String()}');
    costPerWeek = EconomyService.weeklyMedicCost(
      quality,
      teamSize,
      PersonalityTraits.forProfile(enneagramProfile.id, id).thriftiness,
    );
  }

  /// Gibt den Anzeigenamen des Teamarztes zurück.
  String get displayName => 'Dr. $name (${enneagramProfile.name})';

  /// Stößt die Behandlung eines verletzten Charakters an (V3).
  ///
  /// Gibt `true` zurück, wenn die Behandlung erfolgreich war, andernfalls
  /// `false` (z. B. weil der Arzt nicht hilfsbereit genug ist oder die
  /// Behandlung fehlschlägt).
  ///
  /// Die eigentliche Stufenheilung läuft **deterministisch in Echtzeit** über
  /// das Zeitsystem (`GameClockService.advanceHealing`, § 4.3): diese Methode
  /// startet lediglich die Verletzungsuhr (`injuryStartedAt`), falls sie noch
  /// nicht läuft.
  ///
  /// Die Erfolgswahrscheinlichkeit hängt deterministisch von der
  /// [MedicQuality] und dem Enneagramm-Profil ab (V5: keine Fuzzy-Auswertung).
  bool treatCharacter(ObjectApprentice character) {
    // Nur verletzte Charaktere behandeln
    if (character.status == CharacterStatus.ready ||
        character.status == CharacterStatus.dead ||
        character.status == CharacterStatus.overkilled) {
      return false;
    }

    // V9 § 6: Der Erschöpfungs-Malus des Charakters mindert die Arzt-Proben.
    final exhaustion =
        StressService.malusPercentForCharacter(character, _now());

    // Hilfsbereitschaft evaluieren: W100-Wurf gegen den aktuellen
    // helpfulness-Wert (Mittelwert der Fuzzy-Mengen).
    final helpfulnessScore = _evaluateHelpfulness();
    if (EconomyService.rollD100(_random) >
        StressService.targetAfterMalus(helpfulnessScore, exhaustion)) {
      return false; // Arzt ist nicht hilfsbereit genug.
    }

    // Behandlungsqualität evaluieren.
    final qualityScore = _evaluateTreatmentQuality();
    if (EconomyService.rollD100(_random) >
        StressService.targetAfterMalus(qualityScore, exhaustion)) {
      return false; // Behandlung schlägt fehl.
    }

    // Behandlung angestoßen: Die Heilung läuft jetzt in Echtzeit (V3, § 4.3);
    // eine bereits laufende Verletzungsuhr bleibt unangetastet.
    if (character.injuryStartedAt == null) {
      character.injuryStartedAt = _now();
      character.injuryStartStatus = character.status;
    }
    return true;
  }

  /// Gibt den Bonus auf den Rettungswurf-Zielwert zurück, den dieser
  /// Teamarzt bietet.
  ///
  /// Gemäß team_rules.md Abschnitt 4.2:
  /// - Basis-Bonus ist qualitätsabhängig (10/20/30, [EconomyBalance.medicQualitySpecs]).
  /// - Modifiziert durch die Behandlungsqualität (deterministisch, V5).
  int get effectiveSurvivalBonus {
    final baseBonus = EconomyBalance.medicQualitySpecs[quality]!.survivalBonus;
    final qualityModifier = _evaluateTreatmentQuality() ~/
        EconomyBalance.medicQualityModifierDivisor;
    return baseBonus + qualityModifier;
  }

  /// Gibt einen deterministischen Score für das Enneagramm-Profil (0–96).
  ///
  /// Verwendet den Index des Profils in der `all`-Liste, um einen
  /// reproduzierbaren und zwischen Runs/Plattformen konsistenten Wert
  /// zu liefern. Ersetzt die frühere `hashCode`-basierte Berechnung,
  /// die nicht portabel war.
  static int _enneagramScore(EnneagramProfile profile) {
    final index = EnneagramProfile.all.indexOf(profile);
    return ((index + 1) * EconomyBalance.medicEnneagramStep) %
        EconomyBalance.medicEnneagramModulo;
  }

  /// Hilfsbereitschaft (0–100) aus Enneagramm-Profil und Qualität.
  ///
  /// Basis 50 Punkte + Enneagramm-Anteil (0–96) + Qualitätsbonus (10–30),
  /// begrenzt auf 0–100 (V5). Rein und deterministisch – ohne Fuzzy-Auswertung.
  static int helpfulnessScoreFor(
    EnneagramProfile profile,
    MedicQuality quality,
  ) =>
      (EconomyBalance.medicHelpfulnessBase +
              _enneagramScore(profile) +
              EconomyBalance.medicQualitySpecs[quality]!.survivalBonus)
          .clamp(EconomyBalance.medicScoreMin, EconomyBalance.medicScoreMax);

  /// Behandlungsqualität (0–100) aus Enneagramm-Profil und Qualität.
  ///
  /// Qualitätsbonus (10–30) + halber Enneagramm-Anteil (0–48),
  /// begrenzt auf 0–100 (V5). Rein und deterministisch – ohne Fuzzy-Auswertung.
  static int treatmentQualityScoreFor(
    EnneagramProfile profile,
    MedicQuality quality,
  ) =>
      (EconomyBalance.medicQualitySpecs[quality]!.survivalBonus +
              (_enneagramScore(profile) ~/
                  EconomyBalance.medicTreatmentQualityDivisor))
          .clamp(EconomyBalance.medicScoreMin, EconomyBalance.medicScoreMax);

  /// Bewertet die aktuelle Hilfsbereitschaft (0–100) dieses Arztes.
  int _evaluateHelpfulness() =>
      helpfulnessScoreFor(enneagramProfile, quality);

  /// Bewertet die aktuelle Behandlungsqualität (0–100) dieses Arztes.
  int _evaluateTreatmentQuality() =>
      treatmentQualityScoreFor(enneagramProfile, quality);

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