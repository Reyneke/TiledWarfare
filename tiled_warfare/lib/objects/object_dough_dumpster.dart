import 'package:tiled_warfare/objects/object_token.dart';

class ObjectDoughDumpster extends ObjectToken {
  ObjectDoughDumpster() : super(
    name: "Dough Dumpster",
    imagePath: "assets/images/token/token_spawner.png"
  );
}

/*
Der Token "Dough Dumpster" ist ein spezieller Token in einem Spiel, der als Spawner für andere Token dient. Er hat die folgenden Eigenschaften:
Er ist unbeweglich und kann nicht von Spielern oder Gegnern bewegt werden.
Er hat keine Angriffs- oder Verteidigungswerte, da er nicht für den Kampf gedacht ist.
Erh at einen Wundwert von 50, was bedeutet, dass er eine hohe Lebensdauer hat und schwer zu zerstören ist.
Er hat einen Schadenswert von 0, da er keine Angriffe ausführt.
Jeder Kampfrunde spawnt er 126 Token vom Typ "Dough Zombie", was bedeutet, dass er eine große Anzahl von Gegnern erzeugt, die die Spieler bekämpfen müssen.
*/