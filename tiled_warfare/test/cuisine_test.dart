import 'package:flutter_test/flutter_test.dart';
import 'package:random_name_generator/random_name_generator.dart';
import 'package:tiled_warfare/models/cuisine.dart';

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
}
