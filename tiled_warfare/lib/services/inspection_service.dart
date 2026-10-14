import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/frt_service.dart';
import 'package:tiled_warfare/services/staff_role_service.dart';
import 'package:tiled_warfare/utils/crc32.dart';

/// Ergebnis einer Hygiene-Inspektion der Behörden (P3, `11a`
/// „Behörden/Inspektionen“).
///
/// Eine Inspektion ist immer *negativ*: Sie erzeugt – wie jede andere Strafe –
/// eine `penaltyCosts`-Buchung im Wochen-Tick. Die Strafe wird wie jede andere
/// um die Strafen-Minderung (`StaffRoleService`) gemindert, also um den
/// passiven Rechtsanwalt, einen aktiven Winkelzug und die
/// **Zertifizierung** (`certification`, § 10).
class InspectionOutcome {
  /// Anker des abgerechneten Blocks (`weekAnchorAt` beim Blockabschluss).
  final DateTime blockAnchor;

  /// Strafe **vor** der Minderung (Euro).
  final int grossFine;

  /// Strafen-Minderung insgesamt (Prozent, 0–100).
  final int reductionPercent;

  /// Tatsächlich gebuchte Strafe (nach der Minderung, Euro).
  final int fine;

  const InspectionOutcome({
    required this.blockAnchor,
    required this.grossFine,
    required this.reductionPercent,
    required this.fine,
  });
}

/// Deterministische **Behörden-Inspektion** als zweite Strafenquelle (P3).
///
/// Bislang erzeugte nur die **aufgedeckte Spieler-Sabotage** (Kapitel 13)
/// Strafen – die Erweiterung **Zertifizierung/Hygiene-Siegel**
/// (`UpgradeType.certification`, `11b` Gruppe D) wäre für defensive Spielweisen
/// damit wirkungslos gewesen. Die Inspektion liefert diese passive Quelle.
///
/// **Kein Zufall, kein versteckter Zustand:** Ob in einem Block geprüft wird,
/// ist eine reine Funktion aus Restaurant-ID und Blockanker (V8-Idempotenz) –
/// ein Replay desselben `catchUp`-Laufs liefert dasselbe Ergebnis, ein erneuter
/// Catch-up mit demselben `now` bucht weder Strafe noch Auslösung erneut. Die
/// Höhe steht zentral in [EconomyBalance] (V7).
///
/// **Ablauf:** Alle `inspectionIntervalWeeks` Blöcke (phasenverschoben je
/// Restaurant, damit nicht alle gleichzeitig geprüft werden) fällt eine Strafe
/// an, deren Basis mit der **Stadtteil-Korruption** steigt (Kapitel 14) und die
/// um die Strafen-Minderung des Personals **und** der Erweiterungen reduziert
/// wird.
class InspectionService {
  InspectionService._();

  /// Fester Wochenzählungs-Anker (rein rechnerisch; die Differenz zu einem
  /// beliebigen Blockanker ist absolut und damit maschinen-/zeitzonenunabhängig).
  static final DateTime _epoch = DateTime.utc(2024, 1, 1);

  /// Phasenverschiebung der Inspektion für [restaurantId] (`0 … interval−1`) –
  /// rein kosmetisch (verteilt die Prüfungen über die Restaurants), aber
  /// deterministisch über den CRC32 der ID.
  static int phaseOf(int restaurantId) {
    final interval = EconomyBalance.inspectionIntervalWeeks;
    if (interval <= 1) return 0;
    return CRC32.compute('inspection-phase:$restaurantId').abs() % interval;
  }

  /// `true`, wenn im Block mit dem Anker [blockAnchor] eine Inspektion des
  /// Restaurants [restaurantId] stattfindet.
  static bool isDue({
    required int restaurantId,
    required DateTime blockAnchor,
  }) {
    final interval = EconomyBalance.inspectionIntervalWeeks;
    if (interval <= 1) return true;
    final weeks = blockAnchor.difference(_epoch).inDays ~/ 7;
    final offset = weeks + phaseOf(restaurantId);
    return (offset % interval + interval) % interval == 0;
  }

  /// Brutto-Strafe einer Inspektion (Euro) bei [corruptionPercent]
  /// Stadtteil-Korruption (0–100): `inspectionFineBase × (1 + f ×
  /// inspectionCorruptionSurchargePercent/100)`.
  static int grossFine({required double corruptionPercent}) {
    final fraction = FrtService.clampCorruption(corruptionPercent) /
        EconomyBalance.frtCorruptionCeilingPercent;
    final surcharge =
        fraction * EconomyBalance.inspectionCorruptionSurchargePercent / 100;
    return (EconomyBalance.inspectionFineBase * (1 + surcharge)).round();
  }

  /// Löst die Inspektion des Blocks [blockAnchor] auf – `null`, wenn keine
  /// fällig ist (siehe [isDue]).
  ///
  /// Fasst `restaurant.budget` **nicht** an: Die geminderte Strafe wird als
  /// [InspectionOutcome.fine] gemeldet und von der Catch-up-Schleife im dortigen
  /// Wochenbudget gebucht (eine Quelle der Wahrheit, wie bei der Sabotage).
  /// [corruptionPercent] überschreibt die im Restaurant gespeicherte Korruption
  /// – der Tick übergibt hier den **fortgeschriebenen** Wert des Blocks.
  static InspectionOutcome? resolve(
    RestaurantData restaurant,
    DateTime blockAnchor, {
    DateTime? now,
    double? corruptionPercent,
  }) {
    if (!isDue(restaurantId: restaurant.id, blockAnchor: blockAnchor)) {
      return null;
    }
    final percent = corruptionPercent ?? restaurant.corruptionPercent;
    final gross = grossFine(corruptionPercent: percent);
    final reduction = StaffRoleService.penaltyReductionPercent(
      restaurant.staffEntries,
      now: now,
      upgrades: restaurant.upgrades,
    );
    final fine = StaffRoleService.reducedPenalty(
      restaurant.staffEntries,
      gross,
      now: now,
      upgrades: restaurant.upgrades,
    );
    return InspectionOutcome(
      blockAnchor: blockAnchor,
      grossFine: gross,
      reductionPercent: reduction,
      fine: fine,
    );
  }
}
