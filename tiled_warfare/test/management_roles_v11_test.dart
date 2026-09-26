import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/management_feature.dart';
import 'package:tiled_warfare/models/management_role.dart';
import 'package:tiled_warfare/models/staff_entry.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/management_feature_service.dart';
import 'package:tiled_warfare/services/staff_role_service.dart';

/// Tests der Verwaltungsrollen aus `11a` E12–E16: Wochenlöhne, passive Effekte,
/// Feature-Fenster, Kompetenz-Skalierung und Sabotage-Wurf (Determinismus).
void main() {
  StaffEntryData entry(ManagementRole role, {int id = 1}) => StaffEntryData(
        id: id,
        name: 'Test',
        kind: RoleKind.management,
        role: role.name,
        costPerWeek: EconomyBalance.managementRoleWagePerWeek[role] ?? 0,
      );

  group('Managementrollen: Löhne & Zuordnung (E12)', () {
    test('jede Rolle hat einen Lohn und ein Feature (oder bewusst keines)', () {
      for (final role in kAllManagementRoles) {
        expect(EconomyBalance.managementRoleWagePerWeek[role], isNotNull,
            reason: 'Fehlender Wochenlohn für $role');
        expect(EconomyBalance.managementRoleWagePerWeek[role]!, greaterThan(0));
      }
      expect(managementFeatureOf(ManagementRole.chefSecretary),
          ManagementFeature.sabotage);
      expect(managementFeatureOf(ManagementRole.lawyer),
          ManagementFeature.legalTrick);
      expect(managementFeatureOf(ManagementRole.accountant),
          ManagementFeature.creativeAccounting);
    });

    test('die bestehenden Einkommens-Zuschläge bleiben unverändert', () {
      final income = StaffRoleService.managementIncomePercent(
          [entry(ManagementRole.socialMediaManager)]);
      expect(income, EconomyBalance.socialMediaManagerIncomePercent);
      // Die neuen Rollen wirken auf Kosten/Strafen, nicht auf das Einkommen.
      expect(StaffRoleService.managementIncomePercent(
          [entry(ManagementRole.chefSecretary)]), 0);
      expect(StaffRoleService.managementIncomePercent(
          [entry(ManagementRole.lawyer)]), 0);
      expect(StaffRoleService.managementIncomePercent(
          [entry(ManagementRole.accountant)]), 0);
    });
  });

  group('Passive Effekte (E12)', () {
    test('Chefsekretärin mindert Mitarbeiter- und Anschaffungskosten', () {
      expect(StaffRoleService.chefSecretaryStaffCostReductionPercent(
              [entry(ManagementRole.chefSecretary)]),
          EconomyBalance.chefSecretaryStaffCostReductionPercent);
      expect(StaffRoleService.chefSecretaryUpgradeCostReductionPercent(
              [entry(ManagementRole.chefSecretary)]),
          EconomyBalance.chefSecretaryUpgradeCostReductionPercent);
      expect(
          StaffRoleService.chefSecretaryStaffCostReductionPercent(
              [entry(ManagementRole.lawyer)]),
          0);
    });

    test('Buchhalter mindert alle laufenden Kosten', () {
      expect(StaffRoleService.accountantOngoingCostReductionPercent(
              [entry(ManagementRole.accountant)]),
          EconomyBalance.accountantOngoingCostReductionPercent);
      expect(StaffRoleService.accountantOngoingCostReductionPercent(
              [entry(ManagementRole.chefSecretary)]), 0);
    });

    test('Rechtsanwalt: passiv + aktiver Winkelzug, gedeckelt auf 100 %', () {
      final lawyer = entry(ManagementRole.lawyer, id: 1); // Kompetenz 2
      final passive = StaffRoleService.penaltyReductionPercent([lawyer]);
      expect(passive, EconomyBalance.lawyerPenaltyReductionPercent);

      final active = StaffEntryData(
        id: 1,
        name: 'Test',
        kind: RoleKind.management,
        role: ManagementRole.lawyer.name,
        costPerWeek: EconomyBalance.managementRoleWagePerWeek[
            ManagementRole.lawyer]!,
        activeFeature: ManagementFeature.legalTrick.name,
        featureActivatedAt: DateTime(2026, 1, 1),
      );
      final now = DateTime(2026, 1, 2);
      final combined = StaffRoleService.penaltyReductionPercent([active],
          now: now);
      expect(
        combined,
        EconomyBalance.lawyerPenaltyReductionPercent +
            ManagementFeatureService.legalTrickReductionPercentFor(active),
      );

      // Kompetenz 4 negiert die Strafe vollständig (Deckel 100 %).
      final maxed = StaffEntryData(
        id: 3, // competenceOf(3) == 4
        name: 'Test',
        kind: RoleKind.management,
        role: ManagementRole.lawyer.name,
        costPerWeek: 260,
        activeFeature: ManagementFeature.legalTrick.name,
        featureActivatedAt: DateTime(2026, 1, 1),
      );
      expect(StaffRoleService.penaltyReductionPercent([maxed], now: now), 100);
      expect(StaffRoleService.reducedPenalty([maxed], 3000, now: now), 0);
    });

    test('reduceByPercent rundet kaufmännisch und deckelt', () {
      expect(StaffRoleService.reduceByPercent(1000, 0), 1000);
      expect(StaffRoleService.reduceByPercent(1000, 100), 0);
      expect(StaffRoleService.reduceByPercent(1000, 5), 950);
      expect(StaffRoleService.reduceByPercent(3000, 25), 2250);
      expect(StaffRoleService.reduceByPercent(100, 33), 67);
    });
  });
}
