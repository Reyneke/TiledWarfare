import 'package:tiled_warfare/models/restaurant_upgrade.dart';

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

  /// Maximale Negativgrenze (doppelter Startwert).
  static const int negativeLimit = -20000;

  // ── Einmalige Kosten ──────────────────────────────────────────────────

  static const int hireApprenticeCost = 100;
  static const int upgradeToLineCookCost = 500;
  static const int revivalCost = 200;

  // ── Laufende Kosten ───────────────────────────────────────────────────

  /// Basis-Wochenkosten eines Teamarztes (niedrigste Qualität, kleinstes Team).
  static const int medicBaseCostPerWeek = 500;

  /// Zusätzlicher Kostenanteil pro Teammitglied (relativ, 0.05 = +5 %/Kopf).
  static const double medicTeamCostPerHead = 0.05;

  // ── Gefechtsbelohnung (§ 2.2) ─────────────────────────────────────────

  /// Basisprämie bei Sieg (zusätzlich zur Beute).
  static const int battleRewardBaseWin = 200;

  /// Basisprämie bei Niederlage (reduziert).
  static const int battleRewardBaseLoss = 50;

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
