import 'package:tiled_warfare/objects/object_dough_dumpster.dart';
import 'package:random_name_generator/random_name_generator.dart';

class ObjectHost {
  String name = RandomNames(Zone.us).fullName();

  ObjectHost();
  List<ObjectDoughDumpster> doughDumpsterList = [];

  /*
  Singleton
  Der Host ist sowohl für die Spieler als auch für die Gegner zuständig. Er ist ein Singleton, da es nur eine Instanz des Hosts geben kann.
  Der Host steuert die Gegner und ihre Einheiten. Er kann die Gegner in Kämpfen gegen die Spieler einsetzen und ihre Fähigkeiten nutzen, um das Spielziel zu erreichen.
  Weiterhin ist er für die Einhaltung der Regeln verantwortlich, welche in "combat_rules.dart" definiert sind.

  Um ihm eine Persönlichkeit zu geben, kann er mit einem Namen versehen werden. Dieser Name wird in der GUI angezeigt, wenn der Host eine Aktion ausführt.
  Weiterhin wählt er bei jedem Spielbeginn zufällig aus einem der zwölf Eneagramme aus, die unter anderem auf der Webseite "https://en.wikipedia.org/wiki/Enneagram_of_Personality" definiert sind. 
  Diese Enegramme werden durch eine library abgebildet, die auf der Fuzzy Logic Systems library basiert, welche wiederum in "fuzzy_logic/lib/fuzzy_logic.dart" definiert ist.
  */
}
/*
Verhalten der vom Host kontrollierten Gegner und ihrer Einheiten:
Dough Zombies
- bewegen sich gradlinig auf Objekte vom Typ "Line Cook" zu und greifen diese an, wenn sie in Reichweite sind.
- haben eine 25% Chance bei ihrem Tod selbst zu einem Dough Dumpster zu werden, der dann weitere Dough Zombies spawnt.
- haben eine 50% Chance, wenn sie einen Token des Spielers töten, anstelle dieses Tokens einen weiteren Dough Zombie zu spawnen.

Dough Dumpsters spawnen Dough Zombies. Sie spawnen 1w6 (1-6) Dough Zombies und fügen sie der zombieList hinzu. Die Dough Zombies werden dann auf der Karte platziert und bewegen sich auf die Line Cooks zu, um sie anzugreifen.
*/