import 'package:flutter_test/flutter_test.dart';
import 'package:tiled_warfare/models/cuisine.dart';
import 'package:tiled_warfare/models/profile_data.dart';
import 'package:tiled_warfare/objects/object_profile.dart';

/// Baut ein Profil mit genau einem Restaurant. [logoPath] und
/// [profileImagePath] dienen den V4-Ableitungstests.
ProfileData _profileWith({
  String? logoPath,
  String? profileImagePath,
  int restaurantId = 1,
}) =>
    ProfileData(
      id: 42,
      name: 'Testprofil',
      creationDate: DateTime(2026, 1, 1),
      profileImagePath: profileImagePath,
      restaurants: [
        RestaurantData(
          id: restaurantId,
          name: 'Testrestaurant',
          logoPath: logoPath,
        ),
      ],
    );

void main() {
  test('hasCustomImage/headerImagePath leiten aus dem Restaurant-Logo ab', () {
    final profile = ObjectProfile();
    profile.loadFromData(
      _profileWith(logoPath: 'profiles/42/restaurant_1.png'),
      restaurantId: 1,
    );

    expect(profile.hasCustomImage, isTrue);
    expect(profile.headerImagePath, 'profiles/42/restaurant_1.png');
  });

  test('ohne Logo zählt das Profilbild nicht (P2-Regression)', () {
    final profile = ObjectProfile();
    profile.loadFromData(
      _profileWith(profileImagePath: 'profiles/42/profile.png'),
      restaurantId: 1,
    );

    expect(profile.hasCustomImage, isFalse);
    expect(profile.headerImagePath, Cuisine.italian.tokenImagePath);
  });

  test('toProfileData() erhält das Logo (Roundtrip)', () {
    final profile = ObjectProfile();
    profile.loadFromData(
      _profileWith(logoPath: 'profiles/42/restaurant_1.png'),
      restaurantId: 1,
    );

    final saved = profile.toProfileData();
    final restaurant = saved.restaurants.firstWhere((r) => r.id == 1);

    expect(restaurant.logoPath, 'profiles/42/restaurant_1.png');
  });

  test('reset() lässt keinen Alt-Bildzustand zurück', () {
    final profile = ObjectProfile();
    profile.loadFromData(
      _profileWith(logoPath: 'profiles/42/restaurant_1.png'),
      restaurantId: 1,
    );
    final oldId = profile.activeRestaurantId;

    profile.reset();

    expect(profile.restaurantLogoPath, isNull);
    expect(profile.hasCustomImage, isFalse);
    expect(profile.headerImagePath, profile.activeCuisine.tokenImagePath);
    expect(profile.budget, ObjectProfile.startBudget);
    expect(profile.personal, isEmpty);
    expect(profile.hiredMedics, isEmpty);
    expect(profile.activeRestaurantId, isNot(oldId));

    // Der alte Spielstand bleibt (aufgelöst) im Merge erhalten; der neue wird
    // ergänzt – es entsteht kein zweiter Bildzustand und kein Datenverlust.
    final saved = profile.toProfileData();
    final old = saved.restaurants.firstWhere((r) => r.id == oldId);
    expect(old.isDissolved, isTrue);
    expect(saved.restaurants.length, 2);
  });
}
