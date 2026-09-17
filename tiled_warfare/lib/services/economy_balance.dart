import 'package:tiled_warfare/models/management_role.dart';
import 'package:tiled_warfare/models/medic_quality.dart';
import 'package:tiled_warfare/models/restaurant_upgrade.dart';
import 'package:tiled_warfare/models/stations.dart';
import 'package:tiled_warfare/models/support_role.dart';

/// Zentrale Balance-Werte der Wirtschaft (V7).
///
/// Alle Beträge/Peaks der Wirtschaftsschleife leben **hier** – es gibt keine
/// magischen Zahlen mehr im Fluss (`object_profile.dart`,
/// `object_team_medic.dart`, Services usw. delegieren auf diese Klasse).
class EconomyBalance {
  EconomyBalance._();

  // ── Budget ────────────────────────────────────────────────────────────

  /// Startbudget eines neuen Restaurants in Euro.
  static const int startBudget = 10000;

  /// Maximale Negativgrenze (doppelter Startwert, § 2.2 des Regelwerks).
  ///
  /// Bewusst aus [startBudget] abgeleitet, damit ein Tuning des Startbudgets
  /// die Regel „bis zum Doppelten ins Negative“ nicht still bricht (V7/P7).
  static const int negativeLimit = -2 * startBudget;

  // ── Erfahrung & Beförderung (V7/P1, P2) ───────────────────────────────

  /// XP-Basisprämie bei Sieg (zusätzlich zu [xpPerLevelWin] je Level).
  static const int xpBaseWin = 50;

  /// Zusätzliche XP je Charakter-Level bei Sieg.
  static const int xpPerLevelWin = 10;

  /// XP-Basisprämie bei Niederlage.
  static const int xpBaseLoss = 10;

  /// XP-Schwelle pro Level: `levelValue × levelUpXpPerLevel`.
  static const int levelUpXpPerLevel = 1000;

  /// Ab diesem Level ist die Fortbildung „Lehrling → Line Cook“ möglich (§ 2.3).
  static const int lineCookPromotionLevel = 5;

  /// Ab diesem Level ist der Aufstieg zum `Chef de partie` möglich (V10).
  static const int chefDePartiePromotionLevel = 10;

  /// Ab diesem Level ist der Aufstieg zum `Sous-chef` möglich (V10).
  static const int sousChefPromotionLevel = 15;

  /// Ab diesem Level ist der Aufstieg zum `Chef de cuisine` möglich (V10).
  static const int headChefPromotionLevel = 20;

  // ── W100-Domäne (§ 4.2) ───────────────────────────────────────────────

  /// Untere/obere Grenze eines W100-Wurfs.
  static const int d100Min = 1;
  static const int d100Max = 100;

  // ── Zeit (V8) ─────────────────────────────────────────────────────────

  /// Länge eines Wochenticks (1 Echtzeitwoche).
  static const Duration weeklyTick = Duration(days: 7);

  /// Länge eines Tagesschritts (1 Echtzeittag, § 6).
  ///
  /// Der Tag ist die Abgrenzungsebene des passiven Einkommens im
  /// Wochen-Catch-up; `weeklyTick` ist ein ganzzahliges Vielfaches davon
  /// (`dailyTick * 7 == weeklyTick`).
  static const Duration dailyTick = Duration(days: 1);

  // ── Einmalige Kosten ──────────────────────────────────────────────────

  static const int hireApprenticeCost = 100;
  static const int upgradeToLineCookCost = 500;

  /// Einmalkosten der weiteren Karriere-Aufstiege (Karrierepfade, V10).
  static const int upgradeToChefDePartieCost = 1200;
  static const int upgradeToSousChefCost = 3000;
  static const int upgradeToHeadChefCost = 8000;

  static const int revivalCost = 200;

  // ── Personal-Transfer & Karriere-Auren (V10) ──────────────────────────

  /// Transferkosten einer Person: [transferCostBase] plus [transferCostPerLevel]
  /// je Charakter-Level. Das **Ziel-Restaurant zahlt** (Karrierepfade, V10).
  static const int transferCostBase = 200;
  static const int transferCostPerLevel = 50;

  /// Aura-Radius je Karriere-Rang (Hexfelder). Höhere Ränge wirken weiter; der
  /// `Chef de cuisine` wirkt nur in der formellen (kämpfenden) Rolle. Bewusst
  /// als String-Map (Schlüssel = `kRank*`-Werte), um keinen Import-Zyklus zu
  /// `profile_data.dart` zu erzeugen.
  static const Map<String, int> stationAuraRadiusByRank = {
    'chef_de_partie': 1,
    'sous_chef': 2,
    'head_chef': 3,
  };

  // ── Karriere-Stationen (V10, Phase 4) ──────────────────────────────────

  /// Einmalkosten einer **kostenpflichtigen Stations-Wechsel** (Karrierepfade,
  /// V10: „Stations-Wahl: einmalig bindend, mit kostenpflichtigem Wechsel“).
  static const int stationSwitchCost = 150;

  /// Deckel für jeden einzelnen Stations-Bonus in Prozent (V10 § 6).
  static const int stationBonusMaxPercent = 20;

  /// Zusätzlicher Refill-Anteil, den die Support-Station `Pâtissier` den
  /// übrigen Charakteren am Wochen-Refill verschafft (V10, § 2).
  static const int patissierRefillBonusPercent = 10;

  /// Modifikatoren je Station (Werte sind Tuning und gedeckelt über
  /// [stationBonusMaxPercent]). Varianten ersetzen den Bonus ihrer
  /// [StationSpec.baseStation] (kein Stapeln).
  static const Map<String, StationSpec> stationSpecs = {
    kStationSaucier: StationSpec(
      attackBonusPercent: 15,
      auraAttackPercent: 5,
    ),
    kStationPoissonnier: StationSpec(
      attackBonusPercent: 10,
      damageBonusPercent: 5,
      rangeBonusPercent: 20,
      auraDamagePercent: 5,
    ),
    kStationRotisseur: StationSpec(
      damageBonusPercent: 15,
      auraDamagePercent: 5,
    ),
    kStationGrillardin: StationSpec(
      baseStation: kStationRotisseur,
      attackBonusPercent: 5,
      damageBonusPercent: 15,
      auraDamagePercent: 5,
    ),
    kStationFriturier: StationSpec(
      baseStation: kStationRotisseur,
      attackBonusPercent: 5,
      damageBonusPercent: 15,
      rangeBonusPercent: 10,
      auraDamagePercent: 5,
    ),
    kStationEntremetier: StationSpec(
      defenseBonusPercent: 15,
      auraDefensePercent: 5,
    ),
    kStationPotager: StationSpec(
      baseStation: kStationEntremetier,
      defenseBonusPercent: 10,
      damageBonusPercent: 5,
      auraDefensePercent: 5,
    ),
    kStationLegumier: StationSpec(
      baseStation: kStationEntremetier,
      defenseBonusPercent: 10,
      damageBonusPercent: 5,
      auraDefensePercent: 5,
    ),
    kStationGardeManger: StationSpec(
      defenseBonusPercent: 20,
      auraDefensePercent: 5,
    ),
    kStationCharcutier: StationSpec(
      baseStation: kStationGardeManger,
      defenseBonusPercent: 15,
      damageBonusPercent: 5,
      auraDefensePercent: 5,
    ),
    // Support-Station ohne Kampf-Aura: verbessert den Wochen-Refill (V10 § 2).
    kStationPatissier: StationSpec(isSupport: true),
  };

  // ── Chef de cuisine: Management-Profil (V10, Phase 5) ──────────────────

  /// Prozentualer Zuschlag des **aktiven** (zugeteilten) Chef de cuisine auf
  /// die drei Werte des passiven Einkommens (Attraktivität, Kundenzufriedenheit
  /// und Kapazität). Formelle Chefs zählen nicht (Kampf-Profil).
  static const int headChefManagementBuffPercent = 15;

  // ── Wöchentliche Löhne (V10, Phase 7) ──────────────────────────────────

  /// Wochenlohn je Brigade-Rang (Basiswert in Euro, Tuning).
  ///
  /// Schlüssel = `kRank*`-Werte. Der tatsächliche Lohn wird über den
  /// Thriftiness-Faktor des Charakters angepasst
  /// (`EconomyService.staffWagePerWeek`), analog zur Teamarzt-Abrechnung.
  static const Map<String, int> staffWagePerWeekByRank = {
    'apprentice': 100,
    'line_cook': 200,
    'chef_de_partie': 350,
    'sous_chef': 600,
    'head_chef': 1000,
  };

  /// Fallback-Wochenlohn für unbekannte Ränge.
  static const int staffWageFallbackPerWeek = 100;

  // ── Hilfs-/Service-Rollen (V10, Phase 6) ───────────────────────────────

  /// Wochenlohn je Hilfs-/Service-Rolle (Tuning, V10 § 3).
  static const Map<SupportRole, int> supportRoleWagePerWeek = {
    SupportRole.communard: 150,
    SupportRole.tournant: 120,
    SupportRole.aboyeur: 160,
    SupportRole.plongeur: 70,
    SupportRole.commis: 90,
    SupportRole.boucher: 100,
    SupportRole.garcon: 60,
  };

  /// Wochenlohn je **Verwaltungs-/Marketing-Rolle** (Kategorie `management`).
  ///
  /// Grundlage der generalisierten Nicht-Kampf-Personal-Taxonomie (Option C,
  /// `11a`). Die **Wirkung** ist dort noch offen (Entscheidung E3), daher
  /// existiert hier bislang bewusst nur der Lohn – kein Effekt-Const.
  static const Map<ManagementRole, int> managementRoleWagePerWeek = {
    ManagementRole.socialMediaManager: 180,
  };

  /// Einkommens-Zuschlag des **Social Media Manager** auf das passive Einkommen
  /// (Prozent, binär – Entscheidung E3 in `11a`). Stapelt **additiv** mit dem
  /// Aboyeur-Zuschlag (`aboyeurIncomePercent`).
  static const int socialMediaManagerIncomePercent = 10;

  /// Refill-Bonus der Rolle `Communard` auf die Kollegen (Prozent).
  /// Stapelt sich additiv mit dem Pâtissier-Bonus (V10 § 2).
  static const int communardRefillBonusPercent = 15;

  /// Senkung des Erschöpfungs-Malus (Nulltage) durch den `Tournant` (Prozent).
  static const int tournantExhaustionReliefPercent = 25;

  /// Einkommens-Zuschlag des `Aboyeur` auf das passive Einkommen (Prozent).
  static const int aboyeurIncomePercent = 10;

  /// Senkung des Erweiterungs-Unterhalts durch den `Plongeur` (Prozent).
  static const int plongeurUpkeepReductionPercent = 25;

  /// Attraktivitäts-Zuschlag des `Commis` (absolut, auf der Eingangs-Domäne).
  static const double commisAttractivenessBonus = 0.05;

  /// Kleiner Attraktivitäts-/Zufriedenheits-Zuschlag des `Garçon de cuisine`.
  static const double garconAttractivenessBonus = 0.05;
  static const double garconSatisfactionBonus = 0.05;

  /// Beute-Zuschlag des `Boucher` auf die Gefechtsbelohnung (Prozent).
  static const int boucherLootPercent = 10;

  // ── Laufende Kosten ───────────────────────────────────────────────────

  /// Basis-Wochenkosten eines Teamarztes (niedrigste Qualität, kleinstes Team).
  static const int medicBaseCostPerWeek = 500;

  /// Zusätzlicher Kostenanteil pro Teammitglied (relativ, 0.05 = +5 %/Kopf).
  static const double medicTeamCostPerHead = 0.05;

  /// Balance je [MedicQuality]: Kostenmultiplikator, Rettungswurf-Bonus (W100)
  /// und Heilzeit pro Verletzungsstufe (§ 4.3/§ 4.5). Ersetzt die früheren
  /// Tuning-Felder am Enum (V7/L2 – eine Quelle der Wahrheit).
  static const Map<MedicQuality, MedicQualitySpec> medicQualitySpecs = {
    MedicQuality.niedrig: MedicQualitySpec(
      costMultiplier: 1.0,
      survivalBonus: 10,
      healTimePerStage: Duration(hours: 6),
    ),
    MedicQuality.mittel: MedicQualitySpec(
      costMultiplier: 2.0,
      survivalBonus: 20,
      healTimePerStage: Duration(hours: 3),
    ),
    MedicQuality.hoch: MedicQualitySpec(
      costMultiplier: 3.0,
      survivalBonus: 30,
      healTimePerStage: Duration(hours: 1),
    ),
  };

  // ── Teamarzt-Bewertung (V5: deterministisch, 0–100) ────────────────────

  /// Basis-Hilfsbereitschaft (vor Enneagramm- und Qualitätsanteil).
  static const int medicHelpfulnessBase = 50;

  /// Schrittweite des Enneagramm-Anteils in `_enneagramScore`.
  static const int medicEnneagramStep = 8;

  /// Modulo des Enneagramm-Anteils (`(index + 1) × step % modulo`).
  static const int medicEnneagramModulo = 100;

  /// Divisor des Enneagramm-Anteils in der Behandlungsqualität.
  static const int medicTreatmentQualityDivisor = 2;

  /// Divisor für den Qualitätsanteil am effektiven Rettungswurf-Bonus.
  static const int medicQualityModifierDivisor = 10;

  /// Untere/obere Grenze der Arzt-Scores.
  static const int medicScoreMin = 0;
  static const int medicScoreMax = 100;

  // ── Persönlichkeits-Traits (V9) ───────────────────────────────────────

  /// Offset des Profil-Anteils (`(offset + (index + 1) × step) % modulo`).
  static const int personalityTraitOffset = 0;

  /// Schrittweite des Profil-Anteils.
  static const int personalityTraitStep = 8;

  /// Modulo des Profil-Anteils.
  static const int personalityTraitModulo = 100;

  /// Breite der individuellen Varianz je Charakter (±N entspricht ±1W20).
  static const int personalityVarianceRange = 20;

  /// Modulo der Varianz (`(CRC32 % modulo) − range`).
  static const int personalityVarianceModulo = 41;

  /// Untere/obere Grenze der Trait-Werte (0–100).
  static const int personalityTraitMin = 0;
  static const int personalityTraitMax = 100;

  /// Untere/obere Grenze der Ressourcen (`vitalityCurrent`/`moraleCurrent`).
  static const int resourceMin = 0;
  static const int resourceMax = 100;

  /// Ressourcen-Sink pro Echtzeit-Tag (V9, § 2/§ 6).
  static const int resourceSinkPerDay = 5;

  /// Ressourcen-Sink je Gefechtseinsatz (V9, § 2/§ 6).
  static const int resourceSinkPerBattle = 10;

  /// Gewicht der Personal-Hilfsbereitschaft auf die Attraktivität (V9, Phase 3).
  static const double personalityAttractivenessWeight = 0.25;

  /// Max. Lohn-Spanne des Teamarztes (± %) aus seiner Thriftiness (V9, Phase 3).
  static const double thriftinessWageSpread = 0.2;

  // ── Stress & Ruhe / Erschöpfung (V9, § 6) ─────────────────────────────

  /// Ruhe-Marge: Unterschreitung der Probe, ab der „Ruhe“ ausgelöst wird (§ 6).
  static const int ruheMargin = 20;

  /// Dauer eines „Einzelticks“ – reine Zeiteinheit, kein eigener Tick (§ 6).
  static const Duration einzelTickUnit = Duration(hours: 3);

  /// Staffelgrenzen der Über-/Unterschreitung (§ 6).
  static const int stressMarginSingleTick = 5;
  static const int stressMarginDays = 15;
  static const int stressMarginWeeks = 25;

  /// Würfel und Zeiteinheiten der Dauerstaffel (1W6 / 1W4).
  static const int stressDiceW6 = 6;
  static const int stressDiceW4 = 4;
  static const Duration stressDayUnit = Duration(days: 1);
  static const Duration stressWeekUnit = Duration(days: 7);
  static const Duration stressMonthUnit = Duration(days: 30);

  /// Erschöpfungs-Malus je Nulltag (§ 6): +5 pp, bei beiden auf 0 +10 pp.
  static const int resourceZeroMalusPerDay = 5;
  static const int resourceZeroMalusPerDayBoth = 10;

  /// Max. Trait-Modifikator auf Kampf-Zielwerte (± %, V9 Phase 5).
  static const double combatTraitMaxPercent = 15.0;

  // ── Gefechtsbelohnung (§ 2.2) ─────────────────────────────────────────

  /// Basisprämie bei Sieg (zusätzlich zur Beute).
  static const int battleRewardBaseWin = 200;

  /// Basisprämie bei Niederlage (reduziert).
  static const int battleRewardBaseLoss = 50;

  // ── Heilung & Zeit (V3) ───────────────────────────────────────────────

  /// Vollständige Trefferpunkte (Wundstufen) eines Charakters.
  ///
  /// `ready` startet das Gefecht wieder mit vollem Wert; der Startwert wird
  /// über `GameClockService.woundValueFor(status)` aus dem Status abgeleitet
  /// (eine Quelle der Wahrheit).
  static const int maxWoundValue = 3;

  /// Heilzeit pro Verletzungsstufe **ohne** Teamarzt (V3, § 4.3).
  static const Duration healBasePerStage = Duration(hours: 24);

  /// Einmalige Kosten einer (automatisch verabreichten) Notfall-Spritze (§ 4.5).
  static const int emergencyShotCost = 0;

  /// Wirkungsdauer der Notfall-Spritze bis zum Rückfall (§ 4.5).
  static const Duration emergencyShotDuration = Duration(hours: 24);

  // ── Passives Einkommen / Fuzzy-Modell (§ 8) ───────────────────────────

  static const int passiveIncomePerCustomerPerWeek = 5;
  static const double attractivenessBase = 1.0;
  static const double satisfactionBase = 1.0;
  static const double staffAttractivityPerHead = 0.1;

  /// Gewicht der Teamgesundheit in der Kundenzufriedenheit (§ 8).
  ///
  /// Bewusst moderat: Bei vollem Gewicht (z. B. 4.0) sättigt ein gesundes Team
  /// die Zufriedenheit sofort am Domänen-Clamp, wodurch Sieg-/Niederlage-Bonus,
  /// Erweiterungen und Rebranding-Malus wirkungslos würden.
  static const double satisfactionHealthWeight = 1.5;
  static const double satisfactionWinBonus = 0.5;
  static const double satisfactionLossPenalty = 0.5;
  static const int capacityMoneyNorm = 100;
  static const double capacityMax = 20.0;

  // ── Fuzzy-Modell „Kunden/Woche" (§ 8, V7) ─────────────────────────────
  //
  // Alle Peaks/Sätze des passiven Einkommens leben hier, damit Tuning ohne
  // Eingriff in `passive_income_service.dart` möglich ist.

  /// Obere Grenze der Fuzzy-Eingänge Attraktivität/Kundenzufriedenheit
  /// (Domäne 0–4, siehe Balancing-Hinweis in § 8).
  static const double inputDomainMax = 4.0;

  /// Obere Grenze der Ausgangsmenge „Kunden/Woche" (Domäne 0–100).
  static const int customersDomainMax = 100;

  /// Peaks der Eingangsmengen Attraktivität & Kundenzufriedenheit (0–4).
  static const double fuzzyInputLowPeak = 0.75;
  static const double fuzzyInputMidPeak = 2.0;
  static const double fuzzyInputHighPeak = 3.25;

  /// Peaks der Eingangsmenge Kapazität (0–`capacityMax`).
  static const double fuzzyCapacityLowPeak = 2.0;
  static const double fuzzyCapacityMidPeak = 8.0;
  static const double fuzzyCapacityHighPeak = 14.0;

  /// Repräsentant der Ausgangsmenge „Wenig" (Kunden/Woche).
  ///
  /// Bewusst > 0: Ein frisches Restaurant (nur Lehrlinge) erwirtschaftet so ein
  /// kleines, aber spürbares passives Einkommen (§ 8).
  static const int fuzzyFewRepresentative = 20;

  /// Peak der Ausgangsmenge „Mittel" (Kunden/Woche).
  static const int fuzzyCustomersMidPeak = 50;

  /// Stadtteil-Prestige (Default 1.0 für nicht gelistete Stadtteile).
  ///
  /// Die Keys sind **exakt** die Namen aus der Objektebene „Nachbarschaften“
  /// in `assets/world/theworld.tmx`. Werte um 1.0 (orientiert am realen
  /// Prestige-/Preisniveau der Manhattan-Nachbarschaften).
  static const Map<String, double> districtPrestige = {
    // S – höchstes Prestige/Preisniveau
    'TriBeCa': 2.00,
    // A – sehr begehrt
    'Upper East Side': 1.90,
    'SoHo': 1.90,
    'Upper West Side': 1.80,
    'Greenwhich Village / West Village': 1.80,
    'Hudson Yards': 1.60,
    // B – etabliert wohlhabend / trendy
    'Gramercy': 1.50,
    'Flatiron District': 1.50,
    'Nomad': 1.50,
    'Chelsea': 1.40,
    'Financial District': 1.30,
    // C – gemischt / hohe Frequenz
    'Midtown': 1.25,
    'East Village': 1.15,
    'Theater District': 1.15,
    'Koreatown': 1.05,
    'Hell\'s Kitchen': 1.00,
    'Lower East Side': 1.00,
    // D – aufstrebend / working-class
    'Little Italy': 0.90,
    'Chinatown': 0.80,
    'Harlem': 0.70,
  };

  /// Liefert das Prestige eines Stadtteils (Default 1.0, falls unbekannt/null).
  static double districtPrestigeFor(String? district) =>
      (district != null ? districtPrestige[district] : null) ?? 1.0;

  // ── Zinsen ────────────────────────────────────────────────────────────

  static const double negativeInterestRate = 0.10;

  // ── Rettungswurf (W100) ───────────────────────────────────────────────

  static const int survivalBase = 50;
  static const int survivalPerLevel = 10;
  static const int survivalDefenseThreshold = 30;
  static const int survivalPerDefenseOverThreshold = 5;
  static const int survivalOverkillPenalty = 10;

  // ── Rebranding (§ 9) ──────────────────────────────────────────────────

  /// Einmalige Kosten eines Küchenwechsels.
  static const int rebrandingCost = 5000;

  /// Zeitlich begrenzter Attraktivitäts-Malus nach einem Rebranding.
  static const double rebrandingAttractivityPenalty = 1.0;

  /// Dauer des Rebranding-Malus in Wochen.
  static const int rebrandingPenaltyWeeks = 2;

  // ── Einheiten & Kampf (V7/L6, P8/P10) ─────────────────────────────────

  /// Kampf-/Belohnungsprofil eines Spieler-Lehrlings (§ 2.3).
  static const UnitStats apprenticeStats = UnitStats(
    attack: 40, defense: 20, movement: 6, damage: 2, range: 3, money: 100, xp: 25,
  );

  /// Kampf-/Belohnungsprofil eines Line Cooks (§ 2.3).
  static const UnitStats lineCookStats = UnitStats(
    attack: 80, defense: 40, movement: 3, damage: 2, range: 3, money: 1000, xp: 100,
  );

  /// Kampfprofil der höheren Karriere-Ränge (V10, Tuning-Vorschläge).
  static const UnitStats chefDePartieStats = UnitStats(
    attack: 110, defense: 55, movement: 3, damage: 3, range: 3, money: 1000, xp: 150,
  );
  static const UnitStats sousChefStats = UnitStats(
    attack: 140, defense: 70, movement: 3, damage: 4, range: 3, money: 1000, xp: 200,
  );

  /// Kampfprofil des **formellen** `Chef de cuisine`. Der aktive Rang kämpft
  /// nicht, sondern wirkt als Management-Rolle (Karrierepfade, V10).
  static const UnitStats headChefFormalStats = UnitStats(
    attack: 160, defense: 80, movement: 2, damage: 5, range: 3, money: 1000, xp: 250,
  );

  /// Kampf-/Belohnungsprofil eines Dough Zombie.
  static const UnitStats doughZombieStats = UnitStats(
    attack: 40, defense: 40, movement: 1, damage: 1, range: 0, money: 100, xp: 25,
  );

  /// Kampf-/Belohnungsprofil des Dough Dumpster (Boss).
  static const UnitStats doughDumpsterStats = UnitStats(
    attack: 0, defense: 0, movement: 0, damage: 0, range: 0,
    money: 1000, xp: 1000, wound: 50,
  );

  /// Prozentualer Angriffs-/Verteidigungs-Modifikator je Treffer pro Runde (§ 7).
  static const int combatModifierPercentPerHit = 5;

  /// Münzwurf-Grenze bei Gleichstand im Kampf: Angreifer gewinnt bei Wurf > Wert.
  static const int tieBreakWinAbove = 51;

  // ── Erweiterungen (§ 10) ──────────────────────────────────────────────

  /// Anteil der investierten Anschaffungssumme, der beim Verkauf erstattet wird.
  static const double upgradeSellRefundRate = 0.5;

  /// Definitionen aller Erweiterungen (Maximalstufe, Kosten-Basis, Boni).
  static const Map<UpgradeType, UpgradeSpec> upgrades = {
    UpgradeType.tables: UpgradeSpec(
      maxLevel: 5,
      buyBaseCost: 100,
      upkeepBaseCostPerWeek: 10,
      capacityBonusPerLevel: 0.01,
      satisfactionBonusPerLevel: 0.01,
    ),
    UpgradeType.kitchen: UpgradeSpec(
      maxLevel: 5,
      buyBaseCost: 200,
      upkeepBaseCostPerWeek: 20,
      capacityBonusPerLevel: 0.05,
    ),
    UpgradeType.signage: UpgradeSpec(
      maxLevel: 5,
      buyBaseCost: 150,
      upkeepBaseCostPerWeek: 15,
      attractivenessBonusPerLevel: 0.05,
    ),
    UpgradeType.decoration: UpgradeSpec(
      maxLevel: 5,
      buyBaseCost: 120,
      upkeepBaseCostPerWeek: 12,
      attractivenessBonusPerLevel: 0.02,
      satisfactionBonusPerLevel: 0.02,
    ),
    UpgradeType.jukebox: UpgradeSpec(
      maxLevel: 1,
      buyBaseCost: 500,
      upkeepBaseCostPerWeek: 50,
      attractivenessBonusPerLevel: 0.20,
    ),
  };
}

/// Balance-Definition einer Küchenstation (Karrierepfade, V10).
///
/// Alle Prozentwerte sind Tuning-Werte; `EconomyService.stationBonusPercent`
/// deckelt sie über [EconomyBalance.stationBonusMaxPercent]. Die Selbstwirkung
/// (`*BonusPercent`) gilt für den Stationsinhaber, die Aura-Werte
/// (`aura*Percent`) zusätzlich für verbündete Einheiten im Radius.
class StationSpec {
  /// Prozent-Bonus auf den Angriffswert (Selbstwirkung).
  final int attackBonusPercent;

  /// Prozent-Bonus auf den Verteidigungswert (Selbstwirkung).
  final int defenseBonusPercent;

  /// Prozent-Bonus auf den Schadenswert (Selbstwirkung).
  final int damageBonusPercent;

  /// Prozent-Bonus auf die Reichweite (Selbstwirkung).
  final int rangeBonusPercent;

  /// Prozent-Bonus auf den Angriffswert verbündeter Einheiten (Aura).
  final int auraAttackPercent;

  /// Prozent-Bonus auf den Verteidigungswert verbündeter Einheiten (Aura).
  final int auraDefensePercent;

  /// Prozent-Bonus auf den Schadenswert verbündeter Einheiten (Aura).
  final int auraDamagePercent;

  /// Basis-Station dieser Variante (`null` für Basis-Stationen). Varianten
  /// ersetzen den Basis-Bonus, sobald die Basis gewählt wurde.
  final String? baseStation;

  /// Support-Station ohne Kampf-Aura (nur `Pâtissier`, V10 § 2).
  final bool isSupport;

  const StationSpec({
    this.attackBonusPercent = 0,
    this.defenseBonusPercent = 0,
    this.damageBonusPercent = 0,
    this.rangeBonusPercent = 0,
    this.auraAttackPercent = 0,
    this.auraDefensePercent = 0,
    this.auraDamagePercent = 0,
    this.baseStation,
    this.isSupport = false,
  });

  /// Prozent-Bonus (Selbstwirkung) für [stat].
  int selfBonusPercent(StationStat stat) => switch (stat) {
        StationStat.attack => attackBonusPercent,
        StationStat.defense => defenseBonusPercent,
        StationStat.damage => damageBonusPercent,
        StationStat.range => rangeBonusPercent,
      };

  /// Prozent-Bonus (Aura) für [stat].
  int auraBonusPercent(StationStat stat) => switch (stat) {
        StationStat.attack => auraAttackPercent,
        StationStat.defense => auraDefensePercent,
        StationStat.damage => auraDamagePercent,
        // Für die Reichweite gibt es (bewusst) keine Aura – Tuning-Entscheidung.
        StationStat.range => 0,
      };
}

/// Balance-Definition einer Teamarzt-Qualität (V7/L2).
///
/// Bündelt die Werte, die zuvor als Tuning-Felder am [MedicQuality]-Enum
/// hingen: Kostenmultiplikator (relativ zu `EconomyBalance.medicBaseCostPerWeek`),
/// Bonus auf den Rettungswurf-Zielwert und Heilzeit pro Verletzungsstufe.
class MedicQualitySpec {
  /// Kostenmultiplikator relativ zum Basis-Wochenpreis.
  final double costMultiplier;

  /// Bonus auf den Rettungswurf-Zielwert (W100).
  final int survivalBonus;

  /// Dauer bis zur Heilung einer Verletzungsstufe.
  final Duration healTimePerStage;

  const MedicQualitySpec({
    required this.costMultiplier,
    required this.survivalBonus,
    required this.healTimePerStage,
  });
}

/// Kampf-/Belohnungsprofil einer Einheit (V7/L6).
///
/// Fasst die Werte zusammen, die zuvor als Konstruktor-Argumente über die
/// Objektklassen verstreut waren (`moneyValue`/`xpValue` sind Belohnungswerte
/// im Sinne von `team_rules.md` § 2.2, die übrigen sind Kampfbalance).
class UnitStats {
  final int attack;
  final int defense;
  final int movement;
  final int damage;
  final int range;
  final int money;
  final int xp;
  final int wound;
  final int fieldOfView;

  const UnitStats({
    required this.attack,
    required this.defense,
    required this.movement,
    required this.damage,
    required this.range,
    required this.money,
    required this.xp,
    this.wound = 3,
    this.fieldOfView = 3,
  });
}
