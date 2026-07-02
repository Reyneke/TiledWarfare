import 'package:tiled_warfare/objects/object_line_cook.dart';

class ObjectPlayer {

List <ObjectLineCook> lineCookList = [];
ObjectPlayer();

/*
Singleton
Dieses Objekt repäsentiert den Spieler und seine Einheiten. Es ist ein Singleton, da es nur eine Instanz des Spielers geben kann.
Der Spieler steuert die Einheiten vom Typ "Line Cook", die in der Liste "lineCookList" gespeichert sind. Jede Einheit hat ihre eigenen Eigenschaften wie Angriff, Verteidigung, Bewegung, Schaden und Reichweite.
Die Einheiten werden vom Spieler gesteuert und können auf der Karte bewegt und eingesetzt werden. Der Spieler kann die Einheiten in Kämpfen gegen Gegner einsetzen und ihre Fähigkeiten nutzen, um das Spielziel zu erreichen.
Jeder Spieler spawnt mindestens eine Einheit vom Typ "Line Cook", die in der Liste "lineCookList" gespeichert wird. Die Einheiten können im Laufe des Spiels verbessert und aufgerüstet werden, um ihre Fähigkeiten zu verbessern und ihre Überlebensfähigkeit zu erhöhen.

Einheiten werden per Drag&Drop auf der Karte platziert und bewegt. Sie können nur auf freien Feldern platziert werden, die nicht von Gegnern oder anderen Einheiten besetzt sind. Die Einheiten können sich auf der Karte bewegen und angreifen, um Gegner zu besiegen und das Spielziel zu erreichen.
Die Bewegung der Einheiten wird durch die Bewegungspunkte bestimmt, die in der Eigenschaft "movementValue" jeder Einheit gespeichert sind. Jede Bewegung verbraucht eine bestimmte Anzahl von Bewegungspunkten, abhängig von der Entfernung und dem Gelände.

Ein rechter Mausklick auf eine Einheit öffnet ein Kontextmenü, in dem der Spieler die verfügbaren Aktionen für die Einheit auswählen kann. Die verfügbaren Aktionen hängen von den Eigenschaften der Einheit und der aktuellen Spielsituation ab. Immer verfügbar sind die Aktionen "Nahkampfangriff" und "Fernkampfangriff".
*/
}