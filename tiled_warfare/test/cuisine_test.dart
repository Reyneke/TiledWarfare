import 'package:flutter_test/flutter_test.dart';
import 'package:random_name_generator/random_name_generator.dart';
import 'package:tiled_warfare/models/cuisine.dart';
import 'package:tiled_warfare/objects/player_objects/object_apprentice.dart';
import 'package:tiled_warfare/objects/player_objects/object_line_cook.dart';

void main() {
  test('Küche → Zone-Mapping (§ 9)', () {
    expect(Cuisine.italian.zone, Zone.italy);
    expect(Cuisine.japanese.zone, Zone.japan);
    expect(Cuisine.chinese.zone, Zone.china);
    expect(Cuisine.german.zone, Zone.germany);
    expect(Cuisine.canadian.zone, Zone.canada);
    expect(Cuisine.mexican.zone, Zone.spain);
  });

  test('fromName rundreist und fällt auf italienisch zurück', () {
    expect(Cuisine.fromName('japanese'), Cuisine.japanese);
    expect(Cuisine.fromName('mexican'), Cuisine.mexican);
    expect(Cuisine.fromName('unknown'), Cuisine.italian);
    expect(Cuisine.fromName(null), Cuisine.italian);
  });

  test('Küchen-Token-Pfad folgt der Asset-Konvention (§ 9)', () {
    expect(
      Cuisine.italian.tokenImagePath,
      'assets/images/token/token_cook_italian.png',
    );
    expect(
      Cuisine.japanese.tokenImagePath,
      'assets/images/token/token_cook_japanese.png',
    );
    expect(
      Cuisine.chinese.tokenImagePath,
      'assets/images/token/token_cook_chinese.png',
    );
    expect(
      Cuisine.german.tokenImagePath,
      'assets/images/token/token_cook_german.png',
    );
    expect(
      Cuisine.canadian.tokenImagePath,
      'assets/images/token/token_cook_canadian.png',
    );
    expect(
      Cuisine.mexican.tokenImagePath,
      'assets/images/token/token_cook_mexican.png',
    );
  });

  test('Personal nutzt die Küchen-Token-Grafik, Alt-Daten bleiben generisch',
      () {
    final apprentice = ObjectApprentice(cuisine: Cuisine.japanese);
    expect(apprentice.imagePath, Cuisine.japanese.tokenImagePath);

    final lineCook = ObjectLineCook(cuisine: Cuisine.mexican);
    expect(lineCook.imagePath, Cuisine.mexican.tokenImagePath);

    // Legacy: keine Küche (z. B. Deserialisierung alter Spielstände) → Basis.
    final legacy = ObjectApprentice();
    expect(legacy.imagePath, 'assets/images/token/token_cook_basic.png');
  });
}

