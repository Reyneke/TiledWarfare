import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/models/support_role.dart';
import 'package:tiled_warfare/services/economy_balance.dart';

/// Auswertung der Hilfs-/Service-Rollen (Karrierepfade, V10 – Phase 6).
///
/// Die Rollen wirken **nicht** im Gefecht, sondern auf die Management-Schleife.
/// Alle Effekte sind reine Funktionen über die angestellten Rollen, damit sie
/// ohne Widgets testbar bleiben; die Tuning-Werte liegen in `EconomyBalance`.
class SupportRoleService {
  SupportRoleService._();

  /// `true`, wenn [role] im Restaurant vertreten ist.
  static bool has(Iterable<SupportRoleData> roles, SupportRole role) {
    for (final entry in roles) {
      if (entry.role == role.name) return true;
    }
    return false;
  }

  /// Prozentualer Refill-Bonus auf Vitalität/Moral der Kollegen (`Communard`).
  static int refillBonusPercent(Iterable<SupportRoleData> roles) =>
      has(roles, SupportRole.communard)
          ? EconomyBalance.communardRefillBonusPercent
          : 0;

  /// Prozentsatz, um den der Erschöpfungs-Malus gesenkt wird (`Tournant`).
  static int exhaustionReliefPercent(Iterable<SupportRoleData> roles) =>
      has(roles, SupportRole.tournant)
          ? EconomyBalance.tournantExhaustionReliefPercent
          : 0;

  /// Prozentualer Zuschlag auf das passive Einkommen (`Aboyeur`).
  static int incomePercent(Iterable<SupportRoleData> roles) =>
      has(roles, SupportRole.aboyeur)
          ? EconomyBalance.aboyeurIncomePercent
          : 0;

  /// Prozentsatz, um den der Erweiterungs-Unterhalt sinkt (`Plongeur`).
  static int upkeepReductionPercent(Iterable<SupportRoleData> roles) =>
      has(roles, SupportRole.plongeur)
          ? EconomyBalance.plongeurUpkeepReductionPercent
          : 0;

  /// Prozentualer Beute-Zuschlag auf die Gefechtsbelohnung (`Boucher`).
  static int lootPercent(Iterable<SupportRoleData> roles) =>
      has(roles, SupportRole.boucher)
          ? EconomyBalance.boucherLootPercent
          : 0;

  /// Absoluter Attraktivitäts-Zuschlag (`Commis` + `Garçon de cuisine`).
  static double attractivenessBonus(Iterable<SupportRoleData> roles) {
    var bonus = 0.0;
    if (has(roles, SupportRole.commis)) {
      bonus += EconomyBalance.commisAttractivenessBonus;
    }
    if (has(roles, SupportRole.garcon)) {
      bonus += EconomyBalance.garconAttractivenessBonus;
    }
    return bonus;
  }

  /// Absoluter Zufriedenheits-Zuschlag (`Garçon de cuisine`).
  static double satisfactionBonus(Iterable<SupportRoleData> roles) =>
      has(roles, SupportRole.garcon)
          ? EconomyBalance.garconSatisfactionBonus
          : 0.0;

  /// Summe der Wochenlöhne aller angestellten Rollen.
  static int weeklyWages(Iterable<SupportRoleData> roles) {
    var sum = 0;
    for (final entry in roles) {
      sum += entry.costPerWeek;
    }
    return sum;
  }
}
