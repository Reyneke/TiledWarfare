import 'package:tiled_warfare/objects/object_token.dart';

class ObjectLineCook extends ObjectToken {
  ObjectLineCook() : super(
    name: "Line Cook",
    imagePath: "assets/images/token/token_cook_basic.png"
  );
}

/* 
Line Cooks sind Tokens, die vom Spieler kontrolliert werden. Sie sind die Hauptcharaktere, die gegen die Dough Zombies kämpfen.
Sie haben die folgenden Eigenschaften:
attackValue = 40;
defenseValue = 40;
movementValue = 3;
damageValue = 2;
rangeValue = 3;
*/