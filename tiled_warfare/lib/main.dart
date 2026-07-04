import 'package:flutter/material.dart';
import 'package:tiled_warfare/main_app.dart';

void main() {
  runApp(const MainApp());
}
/*
Erklärung: Die Trefferpunkte des Dough Zombie "Karen Hill" scheinen nicht
mit dem Infosheet übereinzustimmen, da zwei Spiellogiken zusammenwirken:

1) Nach einem tötlichen Treffer wird der Spielerzug sofort beendet
   (_checkAutoEndPlayerTurn -> _endPlayerTurn), sobald der Line Cook
   keine Aktionen mehr hat. Der Host übernimmt und lässt den Dough Dumpster
   1w6 neue Zombies spawnen (performAllDumpsterSpawning).

2) Zombies erhalten per Zufall einen Namen aus RandomNames(). Ein neu
   gespawnter Zombie kann zufällig denselben Namen ("Karen Hill") erhalten
   wie der soeben getötete Zombie. Der neue Zombie hat volle 3 Trefferpunkte,
   sodass es aussieht, als hätte der alte Zombie seine HP regeneriert.

Kurz: Der Zombie wurde getötet und entfernt, aber ein neuer Zombie mit
demselben Namen ist an seine Stelle getreten.
*/
