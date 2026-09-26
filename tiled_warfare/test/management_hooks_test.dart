import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/management_feature.dart';
import 'package:tiled_warfare/models/management_role.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/models/restaurant_upgrade.dart';
import 'package:tiled_warfare/objects/object_profile.dart';
import 'package:tiled_warfare/services/economy_balance.dart';
import 'package:tiled_warfare/services/economy_service.dart';
import 'package:tiled_warfare/services/staff_role_service.dart';

/// Integrationstests der V11-Hooks am `ObjectProfile`: Rabatt der Chefsekretärin
/// beim Erweiterungskauf, ziel-lose Feature-Aktivierung (Winkelzug/Kreative
/// Buchführung), Sabotage-Aktivierung sowie die Persistenz des Wirkungsfensters.
void main() {
  ProfileData profileData({int budget = 30000, String? district = 'Midtown'}) =>
      ProfileData(
        id: 7,
        name: 'Testprofil',
        creationDate: DateTime(2026, 1, 1),
        restaurants: [
          RestaurantData(
            id: 1,
            name: 'Testrestaurant',
            district: district,
            budget: budget,
          ),
        ],
      );

  ObjectProfile loaded({int budget = 30000}) {
    final profile = ObjectProfile();
    profile.loadFromData(profileData(budget: budget));
    return profile;
  }

  test('Chefsekretärin mindert den Erweiterungs-Anschaffungspreis', () {
    final profile = loaded();
    final raw = EconomyService.upgradeCost(UpgradeType.tables, 1) -
        EconomyService.upgradeCost(UpgradeType.tables, 0);
    expect(profile.upgradePurchaseCost(UpgradeType.tables), raw);

    profile.hireManagementRole(ManagementRole.chefSecretary);
    expect(
      profile.upgradePurchaseCost(UpgradeType.tables),
      StaffRoleService.reduceByPercent(
        raw,
        EconomyBalance.chefSecretaryUpgradeCostReductionPercent,
      ),
    );

    final cost = profile.upgradePurchaseCost(UpgradeType.tables);
    final before = profile.budget;
    expect(profile.buyUpgrade(UpgradeType.tables), isTrue);
    expect(profile.upgradeLevel(UpgradeType.tables), 1);
    expect(before - profile.budget, cost);
    expect(cost, lessThan(raw));
  });

  test('ziel-lose Features buchen ihre Kosten und sperren den Träger', () {
    final profile = loaded();
    // Ohne angestellten Rechtsanwalt ist keine Aktivierung möglich.
    expect(profile.activateUntargetedFeature(ManagementFeature.legalTrick),
        isFalse);

    profile.hireManagementRole(ManagementRole.lawyer);
    final before = profile.budget;
    expect(profile.activateUntargetedFeature(ManagementFeature.legalTrick),
        isTrue);
    expect(before - profile.budget, EconomyBalance.legalTrickCost);
    // Höchstens ein laufendes Feature pro Träger.
    expect(profile.activateUntargetedFeature(ManagementFeature.legalTrick),
        isFalse);
    expect(profile.managementFeatureIsActive(ManagementFeature.legalTrick,
        now: DateTime.now()), isTrue);
  });

  test('Sabotage braucht die Chefsekretärin und zielt auf einen Rivalen', () {
    final profile = loaded();
    expect(profile.hasChefSecretary, isFalse);
    expect(profile.rivals, isNotEmpty,
        reason: 'Midtown muss ein Rivalen-Feld haben');
    expect(profile.activateSabotage(profile.rivals.first), isFalse);

    profile.hireManagementRole(ManagementRole.chefSecretary);
    expect(profile.hasChefSecretary, isTrue);
    expect(profile.sabotageSuccessPercent, greaterThan(0));
    final before = profile.budget;
    expect(profile.activateSabotage(profile.rivals.first), isTrue);
    expect(before - profile.budget, EconomyBalance.sabotageCost);
    expect(profile.managementFeatureOwner(ManagementFeature.sabotage)
        ?.featureTargetId, profile.rivals.first.id);
  });

  test('das Sabotage-Fenster wird im Restaurant-Snapshot persistiert', () {
    final profile = loaded();
    final until = DateTime(2026, 2, 1);
    profile.sabotageTargetId = profile.rivals.first.id;
    profile.sabotageAppliedUntil = until;

    final snapshot = profile.activeRestaurantSnapshot();
    expect(snapshot.sabotageTargetId, profile.rivals.first.id);
    expect(snapshot.sabotageAppliedUntil, until);
    // Roundtrip über JSON (Schema v8, additiv/tolerant).
    final restored = RestaurantData.fromJson(snapshot.toJson());
    expect(restored.sabotageTargetId, profile.rivals.first.id);
    expect(restored.sabotageAppliedUntil, until);
    // Alte Spielstände ohne die Felder bleiben ladbar.
    final legacy = RestaurantData.fromJson({'id': 1, 'name': 'Alt'});
    expect(legacy.sabotageTargetId, isNull);
    expect(legacy.sabotageAppliedUntil, isNull);
  });
}
