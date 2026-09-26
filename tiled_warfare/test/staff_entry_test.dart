import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/management_role.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/models/staff_entry.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/game_clock_service.dart';
import 'package:tiled_warfare/services/staff_role_service.dart';

/// Tests der generalisierten Nicht-Kampf-Personal-Taxonomie (Option C, `11a`):
/// Kategorie-Datenfeld, Migration aus `supportStaff`, Lohn-Contract.
void main() {
  test('StaffEntryData serialisiert kind und liest tolerant (Option C)', () {
    final entry = StaffEntryData(
      id: 7,
      name: 'Mia',
      kind: RoleKind.management,
      role: 'socialMediaManager',
      costPerWeek: 180,
      hiredAt: DateTime(2026, 5, 1),
    );

    final restored = StaffEntryData.fromJson(entry.toJson());
    expect(restored.id, 7);
    expect(restored.kind, RoleKind.management);
    expect(restored.role, 'socialMediaManager');
    expect(restored.costPerWeek, 180);
    expect(restored.hiredAt, DateTime(2026, 5, 1));

    // Fehlendes `kind` → Küchen-Rolle (Bestände vor der Einführung des Feldes).
    final legacy = StaffEntryData.fromJson({'name': 'Alt'});
    expect(legacy.kind, RoleKind.support);
    expect(legacy.costPerWeek, 0);
    expect(legacy.hiredAt, isNull);
  });

  test('unbekannte Kategorie fällt auf support zurück', () {
    expect(roleKindFromName('management'), RoleKind.management);
    expect(roleKindFromName('medic'), RoleKind.medic);
    expect(roleKindFromName('irgendwas'), RoleKind.support);
    expect(roleKindFromName(null), RoleKind.support);
  });

  test('RestaurantData migriert supportStaff → staffEntries (kind=support)', () {
    final legacy = RestaurantData.fromJson({
      'id': 1,
      'name': 'Alt',
      'supportStaff': [
        {'id': 5, 'name': 'Luigi', 'role': 'plongeur', 'costPerWeek': 70},
      ],
    });

    expect(legacy.staffEntries, hasLength(1));
    expect(legacy.staffEntries.first.kind, RoleKind.support);
    expect(legacy.staffEntries.first.role, 'plongeur');
    expect(legacy.staffEntries.first.costPerWeek, 70);
  });

  test('RestaurantData persistiert staffEntries über JSON-Roundtrip', () {
    final r = RestaurantData(
      id: 2,
      name: 'Neu',
      staffEntries: [
        StaffEntryData(
          id: 1,
          name: 'A',
          kind: RoleKind.support,
          role: 'communard',
          costPerWeek: 150,
        ),
        StaffEntryData(
          id: 2,
          name: 'B',
          kind: RoleKind.management,
          role: 'socialMediaManager',
          costPerWeek: 180,
        ),
      ],
    );

    final restored = RestaurantData.fromJson(r.toJson());
    expect(restored.staffEntries, hasLength(2));
    expect(restored.staffEntries[1].kind, RoleKind.management);
    expect(restored.staffEntries[1].role, 'socialMediaManager');
  });

  test('StaffRoleService gruppiert Kategorien und summiert den Wochenlohn', () {
    final entries = [
      StaffEntryData(
        id: 1,
        name: 'A',
        kind: RoleKind.support,
        role: 'communard',
        costPerWeek: 150,
      ),
      StaffEntryData(
        id: 2,
        name: 'B',
        kind: RoleKind.management,
        role: 'socialMediaManager',
        costPerWeek: 180,
      ),
    ];

    expect(StaffRoleService.ofKind(entries, RoleKind.management), hasLength(1));
    expect(StaffRoleService.hasKind(entries, RoleKind.medic), isFalse);
    expect(StaffRoleService.hasKind(entries, RoleKind.support), isTrue);
    expect(StaffRoleService.hasRole(entries, 'communard'), isTrue);
    expect(StaffRoleService.weeklyWages(entries), 330);
  });

  test('jede ManagementRole hat einen Wochenlohn', () {
    for (final role in kAllManagementRoles) {
      expect(EconomyBalance.managementRoleWagePerWeek[role], isNotNull);
      expect(StaffRoleService.managementWagePerWeek(role), greaterThan(0));
    }
  });

  test('kProfileSchemaVersion ist 8 (Verwaltungsrollen + Rivalen-Modul)', () {
    expect(kProfileSchemaVersion, 8);
  });

  test('managementIncomePercent meldet den Social-Media-Manager-Zuschlag', () {
    expect(StaffRoleService.managementIncomePercent(const []), 0);

    final withManager = [
      StaffEntryData(
        id: 1,
        name: 'A',
        kind: RoleKind.management,
        role: ManagementRole.socialMediaManager.name,
        costPerWeek: 180,
      ),
    ];
    expect(
      StaffRoleService.managementIncomePercent(withManager),
      EconomyBalance.socialMediaManagerIncomePercent,
    );
  });

  test('nonCombatWeeklyWages summiert Support + Management, ohne medic', () {
    final entries = [
      StaffEntryData(
        id: 1,
        name: 'A',
        kind: RoleKind.support,
        role: 'communard',
        costPerWeek: 150,
      ),
      StaffEntryData(
        id: 2,
        name: 'B',
        kind: RoleKind.management,
        role: 'socialMediaManager',
        costPerWeek: 180,
      ),
      StaffEntryData(
        id: 3,
        name: 'C',
        kind: RoleKind.medic,
        role: 'medic',
        costPerWeek: 500,
      ),
    ];
    expect(StaffRoleService.nonCombatWeeklyWages(entries), 330);
  });

  test('Social Media Manager erhöht das passive Einkommen (und kostet Lohn)',
      () {
    final start = DateTime(2026, 1, 1);
    RestaurantData restaurant({List<StaffEntryData> entries = const []}) =>
        RestaurantData(
          id: 1,
          name: 'R',
          budget: 10000,
          district: 'Harlem',
          lastSeenAt: start,
          weekAnchorAt: start,
          staffEntries: entries,
          staff: [
            StaffData(
              name: 'Koch',
              imagePath: 'x.png',
              type: kRankApprentice,
              rank: kRankApprentice,
              id: 4251,
              personalityId: 2,
            ),
          ],
        );

    final plain = restaurant();
    final boosted = restaurant(entries: [
      StaffEntryData(
        id: 1,
        name: 'A',
        kind: RoleKind.management,
        role: ManagementRole.socialMediaManager.name,
        costPerWeek: 180,
      ),
    ]);

    final without =
        GameClockService.catchUp(plain, start.add(const Duration(days: 7)));
    final withRole =
        GameClockService.catchUp(boosted, start.add(const Duration(days: 7)));

    expect(withRole.passiveIncome, greaterThan(without.passiveIncome));
    expect(withRole.staffCosts, greaterThan(without.staffCosts));
  });
}
