import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/management_role.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/models/support_role.dart';
import 'package:tiled_warfare/objects/object_profile.dart';

/// Tests gegen die **Mehrfach-Anstellung** derselben Hilfs-/Service- bzw.
/// Verwaltungsrolle (`11a` E11): jede Rolle darf höchstens einmal vertreten
/// sein; `hire*` ist idempotent.
void main() {
  final start = DateTime(2026, 1, 1);

  ObjectProfile profile() => ObjectProfile()
    ..loadFromData(
      ProfileData(
        id: 7,
        name: 'P',
        creationDate: start,
        restaurants: [RestaurantData(id: 1, name: 'R', budget: 10000)],
      ),
      restaurantId: 1,
    );

  group('Einzelanstellung (11a E11)', () {
    test('Hilfs-/Service-Rolle wird nicht doppelt angestellt', () {
      final p = profile();
      final first = p.hireSupportRole(SupportRole.aboyeur, now: start);
      final second = p.hireSupportRole(SupportRole.aboyeur, now: start);

      expect(p.supportStaffCount, 1);
      expect(second.id, first.id);
      expect(p.hasSupportRole(SupportRole.aboyeur), isTrue);
    });

    test('verschiedene Hilfs-/Service-Rollen bleiben möglich', () {
      final p = profile();
      p.hireSupportRole(SupportRole.aboyeur, now: start);
      p.hireSupportRole(SupportRole.plongeur, now: start);
      expect(p.supportStaffCount, 2);
      expect(p.hasSupportRole(SupportRole.aboyeur), isTrue);
      expect(p.hasSupportRole(SupportRole.plongeur), isTrue);
      expect(p.hasSupportRole(SupportRole.garcon), isFalse);
    });

    test('Verwaltungs-/Marketing-Rolle wird nicht doppelt angestellt', () {
      final p = profile();
      final first = p.hireManagementRole(ManagementRole.lawyer, now: start);
      final second = p.hireManagementRole(ManagementRole.lawyer, now: start);

      expect(p.managementStaff, hasLength(1));
      expect(second.id, first.id);
      expect(p.hasManagementRole(ManagementRole.lawyer), isTrue);
    });

    test('nach Entlassung ist die Rolle wieder einstellbar', () {
      final p = profile();
      p.hireSupportRole(SupportRole.boucher, now: start);
      p.fireSupportRole(p.supportStaff.single);
      expect(p.hasSupportRole(SupportRole.boucher), isFalse);
      p.hireSupportRole(SupportRole.boucher, now: start);
      expect(p.supportStaffCount, 1);
    });
  });
}
